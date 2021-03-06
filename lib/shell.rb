#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require File.expand_path('client',                  File.dirname(__FILE__))
require File.expand_path('parser/adapters/thor',    File.dirname(__FILE__))
require File.expand_path('commands/thor/dtk',       File.dirname(__FILE__))
require File.expand_path('error',                   File.dirname(__FILE__))

# load all from shell directory since those are required
Dir[File.expand_path('shell/**/*.rb', File.dirname(__FILE__))].each { |file| require file }

require 'shellwords'
require 'readline'
require 'colorize'
require 'thor'

# ideas from http://bogojoker.com/readline/#trap_sigint_and_restore_the_state_of_the_terminal

# GLOBAL IDENTIFIER
$shell_mode = true

ALIAS_COMMANDS = {
  'ls' => 'list',
  'cd' => 'cc',
  'rm' => 'delete'
}

class MainContext
  include Singleton

  attr_accessor :context

  def initialize
    @context = DTK::Shell::Context.new
  end

  def self.get_context
    MainContext.instance.context
  end
end

# METHODS

# support for alias commands (ls for list, cd for cc etc.)
def preprocess_commands(original_command)
  command = ALIAS_COMMANDS[original_command]
  # return command if alias for specific command exist in predefined ALIAS_COMMANDS
  # else return entered command because there is no alias for it
  return (command.nil? ? original_command : command)
end
# RUNTIME PART - STARTS HERE

def run_shell_command()
  # init shell client
  init_shell_context()

  # prompt init
  prompt = DTK::Shell::Context::DTK_ROOT_PROMPT

  # trap CTRL-C and remove current text without leaving the dtk-shell
  trap("INT"){
    puts "\n"
    raise Interrupt
  }

  # runtime part
  begin
    while line = Readline.readline(prompt, true)
      prompt = execute_shell_command(line, prompt) unless line.strip.empty?
    end
  rescue DTK::Shell::ExitSignal => e
    # do nothing
  rescue ArgumentError => e
    puts e.backtrace if ::DTK::Configuration.get(:development_mode)
    retry
  rescue Interrupt => e
    retry
  rescue Exception => e
    client_internal_error = DTK::Client::DtkError::Client.label()
    DtkLogger.instance.error_pp("[#{client_internal_error}] #{e.message}", e.backtrace)
  ensure
    puts "\n" unless e.is_a? DTK::Shell::ExitSignal
    # logout
    DTK::Client::Session.logout()
    # save users history
    DTK::Shell::Context.save_session_history(Readline::HISTORY.to_a)
    exit!
  end
end

def init_shell_context()
  begin
    # @context      = DTK::Shell::Context.new
    @shell_header = DTK::Shell::HeaderShell.new

    # loads root context
    MainContext.get_context.load_context()

    @t1   = nil
    Readline.completion_append_character=''
    DTK::Shell::Context.load_session_history().each do |c|
      Readline::HISTORY.push(c)
    end

  rescue DTK::Client::DtkError => e
    DtkLogger.instance.error(e.message, true)
    puts "Exiting ..."
    raise DTK::Shell::ExitSignal
  end
end

def execute_shell_command(line, prompt)
   begin
    # remove single/double quotes from string because shellwords module is not able to parse it
    if matched = line.scan(/['"]/)
      line.gsub!(/['"]/, '') if matched.size.odd?
    end

    # some special cases
    raise DTK::Shell::ExitSignal if line == 'exit'
    return prompt if line.empty?
    if line == 'clear'
      DTK::Client::OsUtil::clear_screen
      return prompt
    end
    # when using help on root this is needed
    line = 'dtk help' if (line == 'help' && MainContext.get_context.root?)

    args = Shellwords.split(line)
    cmd = args.shift

    # support command alias (ls for list etc.)
    cmd = preprocess_commands(cmd)

    # DEV only reload shell
    if ::DTK::Configuration.get(:development_mode)
      if ('restart' == cmd)
        puts "DEV Reloading shell ..."
        ::DTK::Client::OsUtil.dev_reload_shell()
        return prompt
      end
    end


    if ('cc' == cmd)
      # in case there is no params we just reload command
      args << "/" if args.empty?
      prompt = MainContext.get_context.change_context(args, cmd)
    elsif ('popc' == cmd)
        MainContext.get_context.dirs.shift()
        args << (MainContext.get_context.dirs.first.nil? ? '/' : MainContext.get_context.dirs.first)
        prompt = MainContext.get_context.change_context(args, cmd)
    elsif ('pushc' == cmd)
      if args.empty?
        args << (MainContext.get_context.dirs[1].nil? ? '/' : MainContext.get_context.dirs[1])
        MainContext.get_context.dirs.unshift(args.first)
        MainContext.get_context.dirs.uniq!
        prompt = MainContext.get_context.change_context(args, cmd)
      else
        prompt = MainContext.get_context.change_context(args)
        # using regex to remove dtk: and > from path returned by change_context
        # e.g transform dtk:/assembly/node> to /assembly/node
        full_path = prompt.match(/[dtk:](\/.*)[>]/)[1]
        MainContext.get_context.dirs.unshift(full_path)
      end
    elsif ('dirs' == cmd)
      puts MainContext.get_context.dirs.inspect
    else

      # get all next-context-candidates (e.g. for assembly get all assembly_names)
      context_candidates = MainContext.get_context.get_ac_candidates_for_context(MainContext.get_context.active_context.last_context(), MainContext.get_context.active_context())

      # this part of the code is used for calling of nested commands from base context (dtk:/>assembly/assembly_id converge)
      # base_command is used to check if first command from n-level is valid e.g.
      # (dtk:/>assembly/assembly_id converge - chech if 'assembly' exists in context_candidates)
      # revert_context is used to return to context which command is called from after command is executed
      base_command = cmd.split('/').first
      revert_context = false

      if context_candidates.include?(base_command)
        MainContext.get_context.change_context([cmd])
        cmd = args.shift
        revert_context = true
      end

      if cmd.nil?
        prompt = MainContext.get_context.change_context(["-"]) if revert_context
        raise DTK::Client::DtkValidationError, "You have to provide command after context name. Usage: CONTEXT-TYPE/CONTEXT-NAME COMMAND [ARG1] .. [ARG2]."
      end

      # send monkey patch class information about context
      Thor.set_context(MainContext.get_context)

      # we get command and hash params, will return Validation error if command is not valid
      entity_name, method_name, context_params, thor_options, invalid_options = MainContext.get_context.get_command_parameters(cmd,args)

      # check if command is executed from parent context (e.g assembly_name list-nodes)
      if context_candidates.include?(method_name)
        context_params.add_context_to_params(method_name, entity_name, method_name)
        method_name = context_params.method_arguments.shift if context_params.method_arguments.size > 0
      else
        unless MainContext.get_context.method_valid?(method_name)
          prompt = MainContext.get_context.change_context(["-"]) if revert_context
          raise DTK::Client::DtkValidationError, "Method '#{method_name}' is not valid in current context."
        end
      end

      # raise validation error if option is not valid
      raise DTK::Client::DtkValidationError.new("Option '#{invalid_options.first||method_name}' is not valid for current command!", true) unless invalid_options.empty?

      # execute command via Thor
      current_contex_path = MainContext.get_context.active_context.full_path
      top_level_execute(entity_name, method_name, context_params, thor_options, true)

      # when 'delete' or 'delete-and-destroy' command is executed reload cached tasks with latest commands
      unless (args.nil? || args.empty?)
        MainContext.get_context.reload_cached_tasks(entity_name) if (method_name.include?('delete') || method_name.include?('import'))
      end

      # check execution status, prints status to sttout
      DTK::Shell::StatusMonitor.check_status()

      # if we change context while executing command, change prompt as well
      unless current_contex_path.eql?(MainContext.get_context.active_context.full_path)
        prompt = "dtk:#{MainContext.get_context.active_context.full_path}>"
      end

      # after nested command called from base context is executed successfully, return to context which command is executed from
      # this is the same as 'cd -' command is executed
      prompt = MainContext.get_context.change_context(["-"]) if revert_context
    end
  rescue DTK::Client::DSLParsing => e
    DTK::Client::OsUtil.print(e.message, :red)
  rescue DTK::Client::DtkValidationError => e
    DTK::Client::OsUtil.print(e.message, :yellow)
  rescue DTK::Shell::Error => e
    DtkLogger.instance.error(e.message, true)
  end

  return prompt
end

public

def execute_shell_command_internal(line)
  execute_shell_command(line, DTK::Shell::Context::DTK_ROOT_PROMPT)
end
