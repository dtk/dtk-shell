require File.expand_path('client',                  File.dirname(__FILE__))
require File.expand_path('parser/adapters/thor',    File.dirname(__FILE__))
require File.expand_path('commands/thor/dtk',       File.dirname(__FILE__))
require File.expand_path('error',                   File.dirname(__FILE__))

# load all from shell directory since those are required
Dir[File.expand_path('shell/*.rb', File.dirname(__FILE__))].each { |file| require file }

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

# support for alias commands (ls for list etc.)
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

  # runtime part
  begin
    while line = Readline.readline(prompt, true)
      prompt = execute_shell_command(line, prompt)
    end
  rescue DTK::Shell::ExitSignal => e
    # do nothing
  rescue Interrupt => e
    #system('stty', stty_save) # Restore
    puts
  rescue Exception => e
    puts "[CLI INTERNAL ERROR] #{e.message}"
    puts e.backtrace
  ensure
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
    puts e.message
    puts "Exiting ..."
    raise DTK::Shell::ExitSignal
  end
end

def execute_shell_command(line, prompt)
   begin
    # some special cases
    raise DTK::Shell::ExitSignal if line == 'exit'
    return prompt if line.empty?
    if line == 'clear'
      system('clear')
      return prompt
    end
    # when using help on root this is needed
    line = 'dtk help' if (line == 'help' && @context.root?)

    args = Shellwords.split(line)
    cmd = args.shift

    # support command alias (ls for list etc.)
    cmd = preprocess_commands(cmd)
    
    if ('cc' == cmd)
      # in case there is no params we just reload command
      args << "/" if args.empty?      
      prompt = @context.change_context(args)
    elsif ('popc' == cmd)
        args = []
        @context.dirs.shift()
        args << (@context.dirs.first.nil? ? '/' : @context.dirs.first)
        prompt = change_context(args)
    elsif ('pushc' == cmd)
        args << (@context.dirs[1] if args.empty?)
        prompt = change_context(args,true)
    elsif ('dirs' == cmd)
      puts @context.dirs.inspect
    else

      temp_dev_flag = true
      puts "dtk-input > #{cmd} #{args.join(' ')}" if temp_dev_flag

      # send monkey patch class information about context
      Thor.set_context(@context)
      
      # we get command and hash params, will return Validation error if command is not valid
      entity_name, method_name, context_params, thor_options = @context.get_command_parameters(cmd,args)

      # validate method
      unless @context.method_valid?(method_name)
        raise DTK::Client::DtkValidationError, "Method '#{method_name}' is not valid in current context."
      end

      # execute command via Thor
      top_level_execute(entity_name, method_name, context_params, thor_options, true)

      # when 'delete' or 'delete-and-destroy' command is executed reload cached tasks with latest commands
      unless (args.nil? || args.empty?)
        @context.reload_cached_tasks(entity_name) if (method_name.include?('delete') || method_name.include?('import'))
      end       

      # check execution status, prints status to sttout
      DTK::Shell::StatusMonitor.check_status()
    end
  rescue DTK::Client::DtkValidationError => e
    puts e.message.colorize(:yellow)
  rescue DTK::Shell::Error => e
    puts e.message
  end
    
  return prompt
end




