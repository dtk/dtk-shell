require File.expand_path('../commands/thor/dtk', File.dirname(__FILE__))
require File.expand_path('../auxiliary',         File.dirname(__FILE__))
require 'active_support/core_ext/string/inflections'

module DTK
  module Shell
    class Context
      include DTK::Client::Aux

      # client commands
      CLIENT_COMMANDS = ['cc','exit','clear']
      DTK_ROOT_PROMPT = "dtk:/>"

      # current holds context (list of commands) for active context e.g. dtk:\library>
      attr_accessor :current
      attr_accessor :active_commands

      ROOT_TASKS = DTK::Client::Dtk.task_names
      
      def initialize
        @cached_tasks, @active_commands = {}, []
        @conn = DTK::Client::Conn.new()

        if @conn.connection_error?
          @conn.print_warning
          puts "\nDTK will now exit. Please set up your connection properly and try again."
          exit
        end

        @cached_tasks.store('dtk', ROOT_TASKS.sort)

        ROOT_TASKS.each do |task_name|
          # we exclude help since there is no command class for it
          next if task_name.eql? "help"

          # normalize to file_names
          file_name = task_name.gsub('-','_')
          require File.expand_path("../commands/thor/#{file_name}", File.dirname(__FILE__))

          get_latest_tasks(task_name)
        end
      end

      # load context will load list of commands available for given command (passed)
      # to method. Context is list of command available at current tier.
      def load_context(command_name=nil)
        # when switching to tier 2 we need to use command name from tier one
        # e.g. cc library/public, we are caching context under library_1, library_2
        # so getting context for 'public' will not work and we use than library
        command_name = tier_1_command if tier_2?

        # if there is no new context (current) we use old one
        @current = sub_tasks_names(command_name) || @current
        Readline.completion_append_character = " "

        # we add client commands
        @current.concat(CLIENT_COMMANDS).sort!

        # holder for commands to be used since we do not want to remember all of them
        context_commands = @current

        # we load thor command class identifiers for autocomplete context list
        context_commands.concat(get_command_identifiers(command_name)) if tier_1?

        comp = proc { |s| context_commands.grep( /^#{Regexp.escape(s)}/ ) }

        Readline.completion_proc = comp
      end

      # resets context
      def reset
        active_commands.clear
        load_context()
      end

      # when e.g assembly is deleted we want it to be removed from list without
      # exiting dtk-shell
      def reload_cached_tasks(command_name)
        @cached_tasks["#{command_name}_1"].clear
        @cached_tasks["#{command_name}_2"].clear
       
        get_latest_tasks(command_name)

        load_context(command_name)
      end

      # gets current path for shell
      def shell_prompt
        return root? ? DTK_ROOT_PROMPT : "dtk:/#{@active_commands.join('/')}>"
      end

      # returns true if context is on root at the moment
      def root?
        return @active_commands.empty?
      end
      
      # Tier 1 = dtk:/library> 
      def tier_1?
        return @active_commands.size == 1
      end

      # Tier 2 = dtk:/library/public> 
      def tier_2?
        return @active_commands.size == 2
      end

      # checks if change context command is valid
      def command_valid?(command)
        if root?
          unless @current.include? command
            raise DTK::Shell::Error, "Context '#{command}' not present for current tier."
          end
        else
          # at the moment this is tier 1 
          unless valid_id?(tier_1_command(), command)
            raise DTK::Shell::Error, "#{tier_1_command().capitalize} identifier '#{command}' is not valid."
          end
        end
      end

      # returns tier 1 command
      def tier_1_command
        @active_commands.first
      end

      # returns tier 2 command
      def tier_2_command
        @active_commands.last
      end

      # returns list of tasks for given command name
      def sub_tasks_names(command_name=nil)
        # cache works in a way that there are tier 1 and tier 2 list of ta
        sufix = root? ? "" : tier_1? ? "_1" : "_2"
        return @cached_tasks[command_name.to_s+sufix] unless command_name.nil?

        # returns root tasks
        @cached_tasks['dtk']
      end

      # adds command to current list of active commands
      def insert_active_command(command)
        @active_commands << command

        if @active_commands.size > 2
          raise DTK::Shell::Error, "There is error in logic, command chain should be not more than tier 2."
        end
      end

      # remove last active command, and returns it
      def remove_last_command
        @active_commands.pop
      end

      # calls 'valid_id?' method in Thor class to validate ID/NAME
      def valid_id?(thor_command_name,value)
        command_clazz = get_command_class(thor_command_name)
        if command_clazz.respond_to?(:valid_id?)
          return command_clazz.valid_id?(value,@conn)
        end

        # if not implemented we are going to let it in the context
        # TODO: Removed this 'put' after this has been implemented where needed
        puts "[DEV] Implement 'valid_id?' method for thor command class: #{thor_command_name} "
        return false
      end

      # get class identifiers for given thor command, returns array of identifiers
      def get_command_identifiers(thor_command_name)
        command_clazz = get_command_class(thor_command_name)
        if command_clazz.respond_to?(:get_identifiers)
          return command_clazz.get_identifiers(@conn)
        end

        # if not implemented we are going to let it in the context
        # TODO: Removed this 'put' after this has been implemented where needed
        puts "[DEV] Implement 'get_identifiers' method for thor command class: #{thor_command_name} "
        return []
      end

      # changes command and argument if argument is plural of one of 
      # the possible commands on tier1 e.g. libraries, assemblies
      # return 2 values cmd, args
      def reverse_commands(cmd, args)
        # iterates trough current context available commands
        @current.each do |available_commands|
          # singulirazes command, e.g. libraries => library
          command_singular=args.first.singularize
          if available_commands.eql?(command_singular)
            cmd, args = command_singular, [cmd]
          end
        end

        return cmd, args
      end

      private

      def get_command_class(command_name)
        Object.const_get('DTK').const_get('Client').const_get(cap_form(command_name))
      end

      def get_latest_tasks(command_name)
        file_name = command_name.gsub('-','_')
        tier_1_tasks, tier_2_tasks = get_command_class(file_name).tiered_task_names

        # gets thor command class and then all the task names for that command
        @cached_tasks.store("#{command_name}_1",tier_1_tasks)
        @cached_tasks.store("#{command_name}_2",tier_2_tasks)
      end

    end
  end
end


