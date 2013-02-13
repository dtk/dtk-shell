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
      attr_accessor :cached_tasks
      attr_accessor :dirs


      def initialize(skip_caching=false)

        @cached_tasks, @dirs = DTK::Shell::CachedTasks.new, []
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
      
      # Validates and changes context
      def change_context(args)
        begin
            # jump to root
          reset if args.to_s.match(/^\//)

          # Validate and change context
          @active_context, error_message = prepare_context_change(args, @active_context)

          load_context(active_context.last_context_name)

          raise DTK::Client::DtkValidationError, error_message if error_message
        rescue DTK::Client::DtkValidationError => e
          puts e.message.colorize(:yellow)
        rescue DTK::Shell::Error => e
          puts e.message
        rescue Exception => e
          puts e.message
          puts e.backtrace
        ensure
          return shell_prompt
        end
      end

      # this method is used to scan and provide context to be available Readline.complete_proc
      def dynamic_autocomplete_context(readline_input)

        # special case indicator when user starts cc with '/' (go from root)
        goes_from_root = readline_input.start_with?('/')
        # Cloning existing active context, as all changes shouldn't be permanent, but temporary for autocomplete
        active_context_copy = @active_context.clone_me
        # Emptying context copy if it goes from root '/'
        active_context_copy.clear if goes_from_root
        # Invalid context is user leftover to be matched; i.e. 'cc /assembly/te' - 'te' is leftover
        invalid_context = ""

        # Validate and change context; skip step if user's input is empty or it is equal to '/'
        active_context_copy, error_message, invalid_context = prepare_context_change([readline_input], active_context_copy) unless (readline_input.empty? || readline_input == "/")
        
        return get_ac_candidates(active_context_copy, readline_input, invalid_context, goes_from_root)

      end

      def prepare_context_change(args, active_context_copy)

        # split original cc command
        entries = args.first.split(/\//)

        # if only '/' or just cc skip validation
        return active_context_copy if entries.empty?

        current_context_clazz, error_message, current_index = nil, nil, 0
        double_dots_count = DTK::Shell::ContextAux.count_double_dots(entries)

        # we remove '..' from our entries 
        entries = entries.select { |e| !(e.empty? || DTK::Shell::ContextAux.is_double_dot?(e)) }

        # we go back in context based on '..'
        active_context_copy.pop_context(double_dots_count)

        # we add active commands array to begining, using dup to avoid change by ref.
        context_name_list = active_context_copy.name_list
        entries = context_name_list + entries

        # we check the size of active commands
        ac_size = context_name_list.size
        
        invalid_context = ""

        # check each par for command / value
        (0..(entries.size-1)).step(2) do |i|
          command       = entries[i]
          value         = entries[i+1]
          
          clazz = DTK::Shell::Context.get_command_class(command)
          error_message, invalid_context = validate_command(clazz,current_context_clazz,command)
          break if error_message
          # if we are dealing with new entries add them to active_context
          active_context_copy.push_new_context(command, command) if (i >= ac_size)

          current_context_clazz = clazz

          if value
            # context_hash_data is hash with :name, :identifier values
            context_hash_data, error_message, invalid_context = validate_value(command, value, active_context_copy)
            break if error_message
            active_context_copy.push_new_context(context_hash_data[:name], command, context_hash_data[:identifier]) if ((i+1) >= ac_size)
          end
        end

        return active_context_copy, error_message, invalid_context
      end

      def validate_command(clazz, current_context_clazz, command)
        error_message = nil
        invalid_context = ""

        if clazz.nil?
          error_message = "Context for '#{command}' could not be loaded.";
          invalid_context = command
        end
          
        # check if previous context support this one as a child
        unless current_context_clazz.nil?
          # valid child method is necessery to define parent-child relet.
          if current_context_clazz.respond_to?(:valid_child?)
            unless current_context_clazz.valid_child?(command)
              error_message = "'#{command}' context is not valid."
              invalid_context = command
            end
          else
            error_message = "'#{command}' context is not valid."
              invalid_context = command
          end
        end

        return error_message, invalid_context
      end

      def validate_value(command, value, active_context_copy=nil)
        context_hash_data = nil
        invalid_context = ""
         # check value
        if value
          context_hash_data = valid_id?(command, value, nil, active_context_copy)
          unless context_hash_data
            error_message = "Identifier '#{value}' for context '#{command}' is not valid";
            invalid_context = value
          end
        end

        return context_hash_data, error_message, invalid_context
      end

      # load context will load list of commands available for given command (passed)
      # to method. Context is list of command available at current tier.
      def load_context(command_name=nil)
        # when switching to tier 2 we need to use command name from tier one
        # e.g. cc library/public, we are caching context under library_1, library_2
        # so getting context for 'public' will not work and we use than library
        command_name = root? ? 'dtk' : @active_context.last_command_name

        # if there is no new context (current) we use old one
        @current = current_context_task_names() || @current
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
        # we clear @current since this will be reloaded
        @current = nil

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
      def current_context_task_names()
        @cached_tasks.fetch(@active_context.get_task_cache_id(),[]).dup
      end

      # checks if method name is valid in current context
      def method_valid?(method_name)
        # validate method, see if we support given method in current tasks
        (current_context_task_names() + ['help']).include?(method_name)
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
      def valid_id?(thor_command_name,value, override_context_params=nil, active_context_copy=nil)
         
        command_clazz = Context.get_command_class(thor_command_name)
        if command_clazz.list_method_supported?          
          if override_context_params
            context_params = override_context_params
          else
            context_params = get_command_parameters(thor_command_name, [], active_context_copy)[2]
          end
          tmp = command_clazz.valid_id?(value, @conn, context_params)
          return tmp
        end

        # if not implemented we are going to let it in the context
        # TODO: Removed this 'put' after this has been implemented where needed
        puts "[DEV] Implement 'valid_id?' method for thor command class: #{thor_command_name} "
        return nil
      end

      def get_ac_candidates(active_context_copy, readline_input, invalid_context, goes_from_root)
        
        # helper indicator for case when there are more options in current context and cc command is not ended with '/'
        cutoff_forcely = false
        # input string segment used to filter results candidates
        results_filter = (readline_input.match(/\/$/) && invalid_context.empty?) ? "" : readline_input.split("/").last
        results_filter ||= ""

        # If command does not end with '/' check if there are more than one result candidate for current context
        if !readline_input.empty? && !readline_input.match(/\/$/) && invalid_context.empty? && !active_context_copy.empty?
          context_list = active_context_copy.context_list
          context_name = context_list.size == 1 ? nil : context_list[context_list.size-2] # if case when on 1st level, return root candidates
          context_candidates = get_ac_candidates_for_context(context_name, active_context_copy)
          cutoff_forcely = true
        else
          # If last context is command, load all identifiers, otherwise, load next possible context command; if no contexts, load root tasks
          context_candidates = get_ac_candidates_for_context(active_context_copy.last_context(), active_context_copy)
        end

        # checking if results will contain context candidates based on input string segment
        context_candidates = context_candidates.grep( /^#{Regexp.escape(results_filter)}/ )

        # Show all context tasks if active context orignal and it's copy are on same context, and are not on root, 
        # and if readline has one split result indicating user is not going trough n-level, but possibly executing a task
        task_candidates = []
        #task_candidates = @context_commands if (active_context_copy.last_context_name() == @active_context.last_context_name() && !active_context_copy.empty?)
        task_candidates = @context_commands if (active_context_copy.last_context_name() == @active_context.last_context_name() && !active_context_copy.empty? && readline_input.split("/").size == 1)
        
        # create results object filtered by user input segment (results_filter) 
        task_candidates = task_candidates.grep( /^#{Regexp.escape(results_filter)}/ )

        # autocomplete candidates are both context and task candidates; remove duplicates in results
        results = (context_candidates + task_candidates).uniq

        # Send system beep if there are no candidates 
        if results.empty?
          print "\a"
          return []
        end

        # default value of input user string
        input_context_path = readline_input

        # cut off last context if it is leftover (invalid_context), 
        # or if last context is not finished with '/' and it can have more than option for current context
        # i.e. dtk> cc assembly - have 2 candidates: 'assembly' and 'assembly-template'
        if !invalid_context.empty? || cutoff_forcely
          start_index = goes_from_root ? 1 : 0 # if it starts with / don't take first element after split
          input_context_path = readline_input.split("/")[start_index.. -2].join("/")
          input_context_path = input_context_path + "/" unless input_context_path.empty?
          input_context_path = "/" + input_context_path if goes_from_root
        end

        # Augment input string with candidates to satisfy thor
        results = results.map { |element| (input_context_path + element) }

        # If there is only one candidate, and candidate is not task operation
        return (results.size() == 1 && !context_candidates.empty?) ? (results.first + "/") : results

      end

      def get_ac_candidates_for_context(context, active_context_copy)

        # If last context is command, load all identifiers, otherwise, load next possible context command; if no contexts, load root tasks
        if context
          if context.is_command?
            command_identifiers   = get_command_identifiers(context.name, active_context_copy)
            n_level_ac_candidates = command_identifiers ? command_identifiers.collect { |e| e[:name] } : []
          else
            command_clazz = Context.get_command_class(active_context_copy.last_command_name)
            n_level_ac_candidates = command_clazz.respond_to?(:valid_children) ? command_clazz.valid_children.map { |e| e.to_s } : []
          end
        else
          n_level_ac_candidates =  ROOT_TASKS
        end
      end

      # get class identifiers for given thor command, returns array of identifiers
      def get_command_identifiers(thor_command_name, active_context_copy=nil)
        begin
          command_clazz = Context.get_command_class(thor_command_name)
          if command_clazz.list_method_supported?             
            # take just hashed arguemnts from multi return method
            hashed_args = get_command_parameters(thor_command_name, [], active_context_copy)[2]
            return command_clazz.get_identifiers(@conn, hashed_args)
          end
        rescue DTK::Client::DtkValidationError => e
          # TODO Check if handling needed. Error should happen only when autocomplete ID search illigal 
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
        else
          raise DTK::Client::DtkError, "Could not find context \"#{entity_name}\"."
        end

        # if no method specified use help
        method_name ||= 'help'

        context_params.add_context_to_params(entity_name, entity_name) 
        
        if entity_name_id
          identifier_response = valid_id?(entity_name, entity_name_id, context_params)
          if identifier_response
            context_params.add_context_to_params(identifier_response[:name], entity_name, identifier_response[:identifier])
          else
            raise DTK::Client::DtkError, "Could not validate identifier \"#{entity_name_id}\"."
          end
        end

        # extract thor options
        args, thor_options = Context.parse_thor_options(args)
        context_params.method_arguments = args


        unless available_tasks.include?(method_name)
          raise DTK::Client::DtkError, "Could not find task \"#{method_name}\"."
        end

        return entity_name, method_name, context_params, thor_options
      end

      #
      # We use enrich data to help when using dynamic_context loading, Readline.completition_proc
      # See bellow for more details
      #
      def get_command_parameters(cmd,args, active_context_copy=nil)
        # To support autocomplete feature, temp active context may be forwarded into method
        active_context_copy = @active_context unless active_context_copy

        entity_name, method_name = nil, nil

        context_params = ContextParams.new
        
        if root? && !args.empty?
          # this means that somebody is calling command with assembly/.. method_name
          entity_name = cmd
          method_name = args.shift
        else
          context_params.current_context = active_context_copy.clone_me
          entity_name = active_context_copy.name_list.first
          entity_name ||= "dtk"
          method_name = cmd
        end

        # extract thor options
        args, thor_options = Context.parse_thor_options(args)

        # set rest of arguments as method options
        context_params.method_arguments = args

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
        cached_for_command = Context.get_command_class(file_name).tiered_task_names

        # gets thor command class and then all the task names for that command
        @cached_tasks.merge!(cached_for_command)
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


