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
    #system('stty', stty_save) # Restore
    retry
  rescue Exception => e
    DtkLogger.instance.error_pp("[CLI INTERNAL ERROR] #{e.message}", e.backtrace)
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
    @context      = DTK::Shell::Context.new
    @shell_header = DTK::Shell::HeaderShell.new
    # loads root context
    @context.load_context()

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
    line.gsub!(/['"]/, '')

    # some special cases
    raise DTK::Shell::ExitSignal if line == 'exit'
    return prompt if line.empty?
    if line == 'clear'
      DTK::Client::OsUtil::clear_screen
      return prompt
    end
    # when using help on root this is needed
    line = 'dtk help' if (line == 'help' && @context.root?)

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
      prompt = @context.change_context(args, cmd)
    elsif ('popc' == cmd)
        @context.dirs.shift()
        args << (@context.dirs.first.nil? ? '/' : @context.dirs.first)
        prompt = @context.change_context(args, cmd)
    elsif ('pushc' == cmd)
      if args.empty?
        args << (@context.dirs[1].nil? ? '/' : @context.dirs[1])
        @context.dirs.unshift(args.first)
        @context.dirs.uniq!
        prompt = @context.change_context(args, cmd)
      else
        prompt = @context.change_context(args)
        # using regex to remove dtk: and > from path returned by change_context
        # e.g transform dtk:/assembly/node> to /assembly/node
        full_path = prompt.match(/[dtk:](\/.*)[>]/)[1]
        @context.dirs.unshift(full_path)
      end
    elsif ('dirs' == cmd)
      puts @context.dirs.inspect
    else

      # get all next-context-candidates (e.g. for assembly get all assembly_names)
      context_candidates = @context.get_ac_candidates_for_context(@context.active_context.last_context(), @context.active_context())

      # this part of the code is used for calling of nested commands from base context (dtk:/>assembly/assembly_id converge)
      # base_command is used to check if first command from n-level is valid e.g.
      # (dtk:/>assembly/assembly_id converge - chech if 'assembly' exists in context_candidates)
      # revert_context is used to return to context which command is called from after command is executed
      base_command = cmd.split('/').first
      revert_context = false

      if context_candidates.include?(base_command)
        @context.change_context([cmd])
        cmd = args.shift
        revert_context = true
      end

      if cmd.nil?
        prompt = @context.change_context(["-"]) if revert_context
        raise DTK::Client::DtkValidationError, "You have to provide command after context name. Usage: CONTEXT-TYPE/CONTEXT-NAME COMMAND [ARG1] .. [ARG2]."
      end

      # send monkey patch class information about context
      Thor.set_context(@context)

      # we get command and hash params, will return Validation error if command is not valid
      entity_name, method_name, context_params, thor_options, invalid_options = @context.get_command_parameters(cmd,args)

      # check if command is executed from parent context (e.g assembly_name list-nodes)
      if context_candidates.include?(method_name)
        context_params.add_context_to_params(method_name, entity_name, method_name)
        method_name = context_params.method_arguments.shift if context_params.method_arguments.size > 0
      else
        unless @context.method_valid?(method_name)
          prompt = @context.change_context(["-"]) if revert_context
          raise DTK::Client::DtkValidationError, "Method '#{method_name}' is not valid in current context."
        end
      end

      # raise validation error if option is not valid
      raise DTK::Client::DtkValidationError.new("Option '#{invalid_options.first||method_name}' is not valid for current command!", true) unless invalid_options.empty?

      # execute command via Thor
      top_level_execute(entity_name, method_name, context_params, thor_options, true)

      # when 'delete' or 'delete-and-destroy' command is executed reload cached tasks with latest commands
      unless (args.nil? || args.empty?)
        @context.reload_cached_tasks(entity_name) if (method_name.include?('delete') || method_name.include?('import'))
      end

      # check execution status, prints status to sttout
      DTK::Shell::StatusMonitor.check_status()

      # after nested command called from base context is executed successfully, return to context which command is executed from
      # this is the same as 'cd -' command is executed
      prompt = @context.change_context(["-"]) if revert_context
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




