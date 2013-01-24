require File.expand_path('client',                  File.dirname(__FILE__))
require File.expand_path('parser/adapters/thor',    File.dirname(__FILE__))
require File.expand_path('commands/thor/dtk',       File.dirname(__FILE__))
require File.expand_path('error',                   File.dirname(__FILE__))

# load all from shell directory since those are required
Dir[File.expand_path('shell/*.rb', File.dirname(__FILE__))].each {|file| require file }

require 'shellwords'
require 'readline'
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

# Validates and changes context
def change_context(args, push_context = false)
  begin
      # jump to root
    @context.reset if args.to_s.match(/^\//)
    # split original cc command
    entries = args.first.split(/\//)

    # if only '/' or just cc skip validation
    return args if entries.empty?

    current_context_clazz, error_message, current_index = nil, nil, 0
    double_dots_count = DTK::Shell::ContextAux.count_double_dots(entries)

    # we remove '..' from our entries 
    entries = entries.select { |e| !(e.empty? || DTK::Shell::ContextAux.is_double_dot?(e)) }

    # we go back in context based on '..'
    @context.active_context.pop_context(double_dots_count)

    # we add active commands array to begining, using dup to avoid change by ref.
    context_name_list = @context.active_context.name_list
    entries = context_name_list + entries

    # we check the size of active commands
    ac_size = context_name_list.size

    # check each par for command / value
    (0..(entries.size-1)).step(2) do |i|
      command       = entries[i]
      value         = entries[i+1]
      
      clazz = DTK::Shell::Context.get_command_class(command)

      error_message = validate_command(clazz,current_context_clazz,command)
      break if error_message
      # if we are dealing with new entries add them to active_context
      @context.push_to_active_context(command, command) if (i >= ac_size)

      current_context_clazz = clazz

      if value
        # context_hash_data is hash with :name, :identifier values
        context_hash_data, error_message = validate_value(command, value, context_name_list)
        break if error_message
        @context.push_to_active_context(context_hash_data[:name], command, context_hash_data[:identifier]) if ((i+1) >= ac_size)
      end
    end

    puts error_message if error_message

    @context.load_context(@context.active_context.last_context_name)

  rescue DTK::Shell::Error => e
    puts e.message
  rescue Exception => e
    puts e.message
    puts e.backtrace
  ensure
    return @context.shell_prompt
  end
end

def validate_command(clazz, current_context_clazz, command)
  error_message = nil

  if clazz.nil?
    error_message = "Context for '#{command}' could not be loaded.";
  end
    
  # check if previous context support this one as a child
  unless current_context_clazz.nil?
    # valid child method is necessery to define parent-child relet.
    if current_context_clazz.respond_to?(:valid_child?)
      unless current_context_clazz.valid_child?(command)
        error_message = "'#{command}' context is not valid."
      end
    else
      error_message = "'#{command}' context is not valid."
    end
  end

  return error_message
end

def validate_value(command, value, valid_commands)
  context_hash_data = nil
   # check value
  if value
    context_hash_data = @context.valid_id?(command,value,valid_commands)
    unless context_hash_data
      error_message = "Identifier '#{value}' for context '#{command}' is not valid";
    end
  end

  return context_hash_data, error_message
end

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
      prompt = change_context(args)
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

      # we get command and hash params
      entity_name, method_name, hash_args, options_args = @context.get_command_parameters(cmd,args)

      # execute command via Thor
      top_level_execute(entity_name, method_name, hash_args, options_args, true)

      # when 'delete' or 'delete-and-destroy' command is executed reload cached tasks with latest commands
      unless (args.nil? || args.empty?)
        @context.reload_cached_tasks(cmd) if (args.first.include?('delete') || args.first.include?('import'))
      end

      # check execution status, prints status to sttout
      DTK::Shell::StatusMonitor.check_status()
    end

  rescue DTK::Shell::Error => e
    puts e.message
  end
    
  return prompt
end




