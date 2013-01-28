require File.expand_path('../commands/thor/dtk', File.dirname(__FILE__))
require File.expand_path('../auxiliary',         File.dirname(__FILE__))
require 'active_support/core_ext/string/inflections'
require 'json'

module DTK
  module Shell

    class Context
      extend DTK::Client::Aux
      
      # client commands
      CLIENT_COMMANDS       = ['cc','exit','clear','pushc','popc','dirs']
      DTK_ROOT_PROMPT       = "dtk:/>"
      COMMAND_HISTORY_LIMIT = 200
      HISTORY_LOCATION      = DTK::Client::OsUtil.dtk_user_app_folder + "shell_history"
      ROOT_TASKS            = DTK::Client::Dtk.task_names
      ALL_COMMANDS          = ROOT_TASKS + ['component','attribute']

      # current holds context (list of commands) for active context e.g. dtk:\library>
      attr_accessor :current
      attr_accessor :active_context
      attr_accessor :dirs


      def initialize(skip_caching=false)

        @cached_tasks, @dirs = {}, []
        @active_context = ActiveContext.new

        # member used to hold current commands loaded for current command
        @context_commands = []
        @conn = DTK::Client::Session.get_connection()

        # if connection parameters are not set up properly, print warning and exit dtk_shell
        exit if validate_connection(@conn)

        unless skip_caching
          @cached_tasks.store('dtk', ROOT_TASKS.sort)

          ALL_COMMANDS.each do |task_name|
            # we exclude help since there is no command class for it
            next if task_name.eql? "help"

            Context.require_command_class(task_name)

            get_latest_tasks(task_name)
          end
        end
      end

      def self.get_command_class(command_name)
        begin
          Object.const_get('DTK').const_get('Client').const_get(cap_form(command_name))
        rescue Exception => e
          return nil
        end
      end

      def self.require_command_class(command_name)
        # normalize to file_names
        file_name = command_name.gsub('-','_')
        require File.expand_path("../commands/thor/#{file_name}", File.dirname(__FILE__))
      end
      

      # get the correct command
      # /assembly/223232333/nodes/1231232332/attributes
      def calculate_proper_command(delimited_inputs)
        # select last word that is enclosed with //
        # TODO: Fix this later on with proper Regexp           
        match = "/#{delimited_inputs}".match(/\/(.+)\//)
        return nil if match.nil?

        inputs = match[1].split('/')

        if ALL_COMMANDS.include?(inputs.last)
          return inputs.last
        end
        
        return nil
      end

      # this method is used to scan and provide context to be available Readline.complete_proc
      def dynamic_autocomplete_context(readline_input)
        inputs = nil

        n_level_commands = nil

        if readline_input.match /.*\/.*/
          # one before last
          command = calculate_proper_command(readline_input)

          # get inputs from matched data
          if readline_input.match /.*\/$/
            # if last character is '/'
            inputs = readline_input.split(/\//)
            user_input = ''
          else
            # if we have string after last '/'
            inputs = readline_input.split(/\//)
            user_input = inputs.pop
          end

          if command
            command_context   = get_command_identifiers(command, inputs.dup)
            command_name_list = command_context ? command_context.collect { |e| e[:name] } : []
            n_level_commands  = command_name_list
          else
            n_level_commands =  ALL_COMMANDS
          end

        end

        user_input ||= readline_input

        results = (n_level_commands||@context_commands).grep( /^#{Regexp.escape(user_input)}/ )

        unless inputs.nil?
          results = results.map { |element| (inputs.join('/') + '/' + element)}
        end

        return results
      end

      # load context will load list of commands available for given command (passed)
      # to method. Context is list of command available at current tier.
      def load_context(command_name=nil)
        # when switching to tier 2 we need to use command name from tier one
        # e.g. cc library/public, we are caching context under library_1, library_2
        # so getting context for 'public' will not work and we use than library
        command_name = root? ? 'dtk' : @active_context.last_command_name

        # if there is no new context (current) we use old one
        @current = sub_tasks_names(command_name) || @current
        
        # we add client commands
        @current.concat(CLIENT_COMMANDS).sort!

        # holder for commands to be used since we do not want to remember all of them
        @context_commands = @current

        # we load thor command class identifiers for autocomplete context list
        command_context = get_command_identifiers(command_name)
        command_name_list = command_context ? command_context.collect { |e| e[:name] } : []
        @context_commands.concat(command_name_list) if current_command?

        # logic behind context loading
        #Readline.completer_word_break_characters=" "
        Readline.completion_proc = proc { |input| dynamic_autocomplete_context(input) }
      end

      def push_context()
        raise "DEV WE need to RE-IMPLEMENT this."
        @current_path = @active_context.full_path()
        @dirs.unshift(@current_path) unless @current_path.nil?
      end

      # resets context
      def reset
        @active_context.clear
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
        return root? ? DTK_ROOT_PROMPT : "dtk:#{@active_context.full_path}>"
      end

      def root_tasks
        return @cached_tasks['dtk']
      end

      # returns true if context is on root at the moment
      def root?
        return @active_context.empty?
      end
      
      def current_command?
        return @active_context.current_command?
      end

      def current_identifier?
        return @active_context.current_identifier?
      end

      # returns list of tasks for given command name
      def sub_tasks_names(command_name=nil)
        # cache works in a way that there are tier 1 and tier 2 list of ta
        sufix = root? ? "" : current_command? ? "_1" : "_2"
        return @cached_tasks[command_name.to_s+sufix] unless command_name.nil?

        # returns root tasks
        @cached_tasks['dtk']
      end

      # adds command to current list of active commands
      def push_to_active_context(context_name, entity_name, context_value = nil)
        @active_context.push_new_context(context_name, entity_name, context_value)
      end

      # remove last active command, and returns it
      def pop_from_active_context
        return @active_context.pop_context
      end

      # calls 'valid_id?' method in Thor class to validate ID/NAME
      def valid_id?(thor_command_name,value, override_context_params = nil)
         
        command_clazz = Context.get_command_class(thor_command_name)
        if command_clazz.list_method_supported?          
          if override_context_params
            context_params = override_context_params
          else
            context_params = get_command_parameters(thor_command_name,[])[2]
          end
          tmp = command_clazz.valid_id?(value, @conn, context_params)
          return tmp
        end

        # if not implemented we are going to let it in the context
        # TODO: Removed this 'put' after this has been implemented where needed
        puts "[DEV] Implement 'valid_id?' method for thor command class: #{thor_command_name} "
        return nil
      end

      # get class identifiers for given thor command, returns array of identifiers
      def get_command_identifiers(thor_command_name, autocomplete_input = [])
                      
        command_clazz = Context.get_command_class(thor_command_name)
        if command_clazz.list_method_supported?             
          # take just hashed arguemnts from multi return method
          hashed_args = get_command_parameters(thor_command_name,[],autocomplete_input)[2]
          return command_clazz.get_identifiers(@conn, hashed_args)
        end

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

      def get_dtk_command_parameters(entity_name, args)
        method_name, entity_name_id = nil, nil
        context_params = ContextParams.new

        if (ROOT_TASKS + ['dtk']).include?(entity_name)
          Context.require_command_class(entity_name)
          available_tasks = Context.get_command_class(entity_name).task_names
          if available_tasks.include?(args.first)
            method_name = args.shift
          else
            entity_name_id = args.shift
            method_name = args.shift
          end
        end

        # if no method specified use help
        method_name ||= 'help'

        context_params.add_context_to_params(entity_name, entity_name) 
        
        if entity_name_id
          identifier_response = valid_id?(entity_name, entity_name_id, context_params)
          if identifier_response
            context_params.add_context_to_params(identifier_response[:name], entity_name, identifier_response[:identifier])
          end
        end

        # extract thor options
        args, thor_options = Context.parse_thor_options(args)
        context_params.method_arguments = args

        return entity_name, method_name, context_params, thor_options
      end

      #
      # We use enrich data to help when using dynamic_context loading, Readline.completition_proc
      # See bellow for more details
      #
      def get_command_parameters(cmd,args,enrich_data=[])
        entity_name, method_name = nil, nil

        context_params = ContextParams.new
        
        if root? && !args.empty?
          # this means that somebody is calling command with assembly/.. method_name
          entity_name = cmd
          method_name = args.shift
        else
          context_params.current_context = @active_context.clone_me
          entity_name = @active_context.name_list.first
          method_name = cmd
        end

        # extract thor options
        args, thor_options = Context.parse_thor_options(args)

        # set rest of arguments as method options
        context_params.method_arguments = args

        # special part of the code used by autocomplete when active_context is not available
        # meaning ENTER has not been clicked and we are using Readline.completion_proc
        unless enrich_data.empty?
          skip_command = false
             
          if (!root? && @active_context.current_command?)
            skip_command = true
            last_command = @active_context.last_command_name
            enrich_data.unshift(last_command) if last_command
          end

          (0..(enrich_data.size-1)).step(2) do |i|
            command = enrich_data[i]
            value   = enrich_data[i+1]
            
            # we use skip command to make sure that we have proper command / identifier pairs
            # skip commands make sure that we do not duplicate context_params.current_context
            if skip_command
              skip_command = false
            else
              context_params.add_context_to_params(command, command) if command
            end

            # if there is a value and there no more commands
            if value 
              # TODO: Current fix, if we need real ID we need to fix this
                 
              identifier_response = valid_id?(command, value, context_params)

              if identifier_response
                context_params.add_context_to_params(identifier_response[:name], command, identifier_response[:identifier])
              end
            end
          end
        end

        return entity_name, method_name, context_params, thor_options
      end

      private

      #
      # method takes paramters that can hold specific thor options
      #
      def self.parse_thor_options(args)
        # options for the command e.g. --list 
        # and remove options_args from args
        options_args = args.select { |a| a.match(/^\-\-/)}
        args = args - options_args

        # options to handle thor options -m MESSAGE
        options_param_args = []
        args.each_with_index do |e,i|
          if e.match(/^\-[a-zA-Z]?/)
            options_param_args << e
            options_param_args << args[i+1]
          end
        end

        # remove thor_options
        args = args - options_param_args

        return args, (options_args + options_param_args)
      end

      def self.command_to_id_sym(command_name)
        "#{command_name}_id".gsub(/\-/,'_').to_sym
      end

      def get_latest_tasks(command_name)
        file_name = command_name.gsub('-','_')
        tier_1_tasks, tier_2_tasks = Context.get_command_class(file_name).tiered_task_names

        # gets thor command class and then all the task names for that command
        @cached_tasks.store("#{command_name}_1",tier_1_tasks)
        @cached_tasks.store("#{command_name}_2",tier_2_tasks)
      end


      # PART OF THE CODE USED FOR WORKING WITH DTK::Shell HISTORY
      public

      def self.load_session_history()
        return [] unless is_there_history_file()
        content = File.open(HISTORY_LOCATION,'r').read
        return (content.empty? ? [] : JSON.parse(content))
      end

      def self.save_session_history(array_of_commands)
        return [] unless is_there_history_file()
        # we filter the list to remove neighbour duplicates
        filtered_commands = []
        array_of_commands.each_with_index do |a,i|
          filtered_commands << a if (a != array_of_commands[i+1])
        end
             
        # make sure we only save up to 'COMMAND_HISTORY_LIMIT' commands
        if filtered_commands.size > COMMAND_HISTORY_LIMIT
          filtered_commands = filtered_commands[-COMMAND_HISTORY_LIMIT,COMMAND_HISTORY_LIMIT+1]
        end

        File.open(HISTORY_LOCATION,'w') { |f| f.write(filtered_commands.to_json) }
      end

      private

      def self.is_there_history_file()
        unless File.exists? HISTORY_LOCATION
          DtkLogger.instance.info "[INFO] Session shell history has been disabled, please create file '#{HISTORY_LOCATION}' to enable it."
          return false
        end
        return true
      end
    end
  end
end


