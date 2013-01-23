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

def change_context(args, push_context = false)
  args = validate_correct_context(args)
  # this means validation has failed
  return @context.shell_prompt if args.empty?
  change_context_execute(args,push_context)
end

def validate_correct_context(args)
  # jump to root
  @context.reset if args.to_s.match(/^\//)
  # split original cc command
  entries = args.first.split(/\//)

  # if only '/' or just cc skip validation
  return args if entries.empty?

  current_context_clazz, error_message, current_index = nil, nil, 0
  double_dots_count = DTK::Shell::ContextAux.count_double_dots(entries)

  # we add current context to the mix
  current_active_commands = @context.active_commands.dup

  # we go back in context based on '..'
  current_active_commands.pop(double_dots_count)

  # we add active commands array to begining, using dup to avoid change by ref.
  entries = current_active_commands.dup.concat(entries)

  # we remove '..' from our entries 
  entries = entries.select { |e| !(e.empty? || DTK::Shell::ContextAux.is_double_dot?(e)) }
  valid_commands = []

  # check each par for command / value
  (0..(entries.size-1)).step(2) do |i|
    command       = entries[i]
    value         = entries[i+1]
    

    clazz = DTK::Shell::Context.get_command_class(command)

    error_message = validate_command(clazz,current_context_clazz,command)
    break if error_message
    valid_commands << command

    current_context_clazz = clazz

    error_message = validate_value(command, value, valid_commands)
    break if error_message
    valid_commands << value
  end

  puts error_message if error_message

  # we remove active commands since we only needed them for validation,
  # at this point we return input which passed validation.
  # e.g. assembly/2123/nod2e/foo
  # we return assembly/2123 since that part is valid and discard rest.
  valid_commands.shift(current_active_commands.size)

  # we add '..' we ommited if present
  valid_commands.unshift(['..']*double_dots_count) unless double_dots_count == 0

  return valid_commands.join('/')
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
   # check value
  if value
    unless @context.valid_id?(command,value,valid_commands)
      error_message = "Identifier '#{value}' for context '#{command}' is not valid";
    end
  end
end


def change_context_execute(args, push_context=false)
  return DTK::Shell::Context::DTK_ROOT_PROMPT if args.empty?

  begin
    # if separated by spaces join them with '/' so we support spaces and slashes
    if args.instance_of?(Array) && args.size > 1
      args = args.join('/')
    end
    # first command is the one we take context from
    command = args.first
    # check for root of context
    if ('/'.eql?(command[0,1]))
      @context.reset()
      next_command = command[1,command.size]
      return change_context_execute(next_command,push_context)
    end

    # for multi context e.g. `cc library/public`
    if command.include?('/')
      multiple_commands = command.split('/')
      # last command will continue to run in this flow
      command = multiple_commands.pop

      # use recursion to load all other commands first, second, ...
      # flow will continue with last command left to load (see above)
      multiple_commands.each { |m_command| change_context_execute(m_command) }
      # ...
    end
      
    if DTK::Shell::ContextAux.is_double_dot?(command)
      # backtracing context
      @context.remove_last_command
      # since we support two level max this will be tier 1 command or root
      # TODO: FIX THIS
      command = @context.last_command
    else
      # set command to context         
      @context.insert_active_command(command)
    end

    # loads context for given command
    @context.push_context() if push_context
    @context.load_context(command)

  rescue DTK::Shell::Error => e
    puts e.message
  rescue Exception => e
    puts e.message
    puts e.backtrace
  ensure
    return @context.shell_prompt
  end
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

      #if (args.to_s.match(/.\/./) && !args.to_s.start_with?('/'))
      #  @context.valid_pairs(args)
      #  pairs = @context.get_pairs(args)
      #  prompt = change_advanced_context(pairs)
      #else
      #  #changes context based on passed args
      #  prompt = change_context(args)
      #end
      
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
    puts ">>>>>>>>>>>>>>>>>>>"
    puts e.message
  end
    
  return prompt
end

def execute_shell_command_backup(line, prompt)
   begin
    # some special cases
    raise DTK::Shell::ExitSignal if line == 'exit'
    return prompt if line.empty?
    if line == 'clear'
      system('clear')
      return prompt
    end
    # when using help on root this is needed
    line = 'dtk' if (line == 'help' && @context.root?)

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

      # if e.g "list libraries" is sent instead of "library list" we reverse commands
      # and still search for 'library list', this happens only on root
      if !args.empty? && @context.active_commands.empty?
        cmd, args = @context.reverse_commands(cmd, args)
      end

      # we only pre-process commands on Tier 1, Tier 2 on root there is no need
      unless @context.root?
        # command goes as first argument
        args.unshift(cmd)
        # main command is first one from 
        cmd  = @context.tier_1_command()
        # in case there is second cc it means it is ID and goes as first arg
        args.unshift(@context.last_command()) if @context.tier_2?
      end

      temp_dev_flag = true
      puts "dtk-input > #{cmd} #{args.join(' ')}" if temp_dev_flag

      # special case when we are doing help for context we need to remove
      # context paramter
      if @context.tier_2?
        if args.last == 'help'
          # we remove ID/NAME in order for help command to work
          # e.g. library public help => library help
          args.shift
        end
      end

      # send monkey patch class information about context
      Thor.set_context(@context)

      # execute command via Thor
      top_level_execute(cmd,args,true)

      # when 'delete' or 'delete-and-destroy' command is executed reload cached tasks with latest commands
      unless (args.nil? || args.empty?)
        @context.reload_cached_tasks(cmd) if (args.first.include?('delete') || args.first.include?('import'))
      end

      # check execution status, prints status to sttout
      DTK::Shell::StatusMonitor.check_status()
    end

  rescue DTK::Shell::Error => e
    puts ">>>>>>>>>>>>>>>>>>>"
    puts e.message
  end
    
  return prompt
end





