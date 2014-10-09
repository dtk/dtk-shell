require File.expand_path('../commands/thor/dtk', File.dirname(__FILE__))
require File.expand_path('../auxiliary',         File.dirname(__FILE__))
require 'json'

module DTK
  module Shell

    class Context
      include DTK::Client::Auxiliary

      # client commands
      CLIENT_COMMANDS       = ['cc','exit','clear','pushc','popc','dirs','help']
      # CLIENT_COMMANDS       = ['cc','exit','clear','help']
      DEV_COMMANDS          = ['restart']
      DTK_ROOT_PROMPT       = "dtk:/>"
      COMMAND_HISTORY_LIMIT = 200
      HISTORY_LOCATION      = DTK::Client::OsUtil.dtk_local_folder + "shell_history"
      ROOT_TASKS            = DTK::Client::Dtk.task_names
      ALL_COMMANDS          = ROOT_TASKS + DTK::Client::Dtk.additional_entities
      IDENTIFIERS_ONLY      = ['cc','cd','pushc']


      SYM_LINKS = [
        { :alias => :workspace, :path => 'workspace/workspace' }
      ]

      # current holds context (list of commands) for active context e.g. dtk:\library>
      attr_accessor :current
      attr_accessor :active_context
      attr_accessor :cached_tasks
      attr_accessor :dirs


      def initialize(skip_caching=false)
        @cached_tasks, @dirs = DTK::Shell::CachedTasks.new, []
        @active_context   = ActiveContext.new
        @previous_context = nil

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
        ::DTK::Client::OsUtil.get_dtk_class(command_name)
      end

      def self.require_command_class(command_name)
        # normalize to file_names
        file_name = command_name.gsub('-','_')
        require File.expand_path("../commands/thor/#{file_name}", File.dirname(__FILE__))
      end

      # SYM_LINKS methods is used to calculate aliases that will be used for certain entities
      # one of those approaches will be as such
      def self.check_for_sym_link(entries)
        # remove empty strings from array
        entries.reject! { |e| e.empty? }

        if (entries.size > 0)
          SYM_LINKS.each do |sym_link|
            if entries.first.downcase.to_sym.eql?(sym_link[:alias])
              entries[0] = sym_link[:path].split('/')
              entries.flatten!
            end
          end
        end

        entries
      end

      # take current path and see if it is aliased path
      def self.enchance_path_with_alias(path, context_list)
        SYM_LINKS.each do |sym_link|
          if path.downcase.include?(sym_link[:path])
            path = path.gsub(sym_link[:path], sym_link[:alias].to_s)
          end
        end

        unless context_list.empty?
          init_context = context_list.first.name
          command_clazz = Context.get_command_class(init_context)
          invisible_context = command_clazz.respond_to?(:invisible_context) ? command_clazz.invisible_context() : {}

          invisible_context.each do |ic|
            path = path.gsub(/\/#{ic}\//,'/')
          end
        end

        path
      end

      # Validates and changes context
      def change_context(args, cmd=[])
        begin
          # check if we are doing switch context
          if args.join("").match(/\A\-\Z/)
            if @previous_context
              # swap 2 variables
              @active_context, @previous_context = @previous_context, @active_context
            end
            load_context(active_context.last_context_name)
            return
          end

          # remember current context
          @previous_context = @active_context.clone_me()

          # jump to root
          reset if args.join('').match(/^\//)

          # begin
          # hack: used just to avoid entering assembly/id/node or workspace/node context (remove when include this contexts again)
          first_c, warning_message = nil, nil
          first_c = @active_context.context_list().first.name unless @active_context.context_list().empty?
          tmp_active_context = @active_context.clone_me
          restricted = is_restricted_context(first_c, args, tmp_active_context)

          args = restricted[:args]
          warning_message = restricted[:message]
          node_specific = restricted[:node_specific]

          DTK::Client::OsUtil.print(warning_message, :yellow) if warning_message
          # end

          # Validate and change context
          @active_context, error_message = prepare_context_change(args, @active_context, node_specific, cmd, true)

          load_context(active_context.last_context_name)

          raise DTK::Client::DtkValidationError, error_message if error_message
        rescue DTK::Client::DtkValidationError => e
          DTK::Client::OsUtil.print(e.message, :yellow)
        rescue DTK::Shell::Error, Exception => e
          DtkLogger.instance.error_pp(e.message, e.backtrace)
        ensure
          return shell_prompt()
        end
      end

      # this method is used to scan and provide context to be available Readline.complete_proc
      def dynamic_autocomplete_context(readline_input, line_buffer=[])
        # special case indicator when user starts cc with '/' (go from root)
        goes_from_root = readline_input.start_with?('/')
        # Cloning existing active context, as all changes shouldn't be permanent, but temporary for autocomplete
        active_context_copy = @active_context.clone_me
        # Emptying context copy if it goes from root '/'
        active_context_copy.clear if goes_from_root
        # Invalid context is user leftover to be matched; i.e. 'cc /assembly/te' - 'te' is leftover
        invalid_context = ""

        # Validate and change context; skip step if user's input is empty or it is equal to '/'
        active_context_copy, error_message, invalid_context = prepare_context_change([readline_input], active_context_copy, nil, line_buffer) unless (readline_input.empty? || readline_input == "/")

        # using extended_context when we want to use autocomplete from other context
        # e.g. we are in assembly/apache context and want to create-component we will use extended context to add
        # component-templates to autocomplete
        extended_candidates, new_context, line_buffer_first = {}, nil, nil
        command_clazz = Context.get_command_class(active_context_copy.last_command_name)
        # require 'debugger'
        # Debugger.start
        # debugger
        # unless (line_buffer.empty? || line_buffer.strip().empty?)
        #   line_buffer_last = line_buffer.split(' ').last
        #   line_buffer = line_buffer.split(' ').first
        #   line_buffer.gsub!('-','_') unless (line_buffer.nil? || line_buffer.empty?)
        # end

        unless (line_buffer.empty? || line_buffer.strip().empty?)
          line_buffer = line_buffer.split(' ')
          line_buffer_last = line_buffer.last
          line_buffer_first = line_buffer.first
          line_buffer_first.gsub!('-','_') unless (line_buffer_first.nil? || line_buffer_first.empty?)
        end

        unless command_clazz.nil?
          extended_context = command_clazz.respond_to?(:extended_context) ? command_clazz.extended_context() : {}

          unless extended_context.empty?
            extended_context = extended_context[:context]
            # extended_context.reject!{|k,v| k.to_s!=line_buffer}
            # extended_context.select!{|k,v| k.to_s.eql?(line_buffer_first) || k.to_s.eql?(line_buffer_last)}
            extended_context.select!{|k,v| line_buffer.include?(k.to_s)} if extended_context.respond_to?(:select!)

            if (extended_context[line_buffer_last] && !line_buffer_first.eql?(line_buffer_last))
              new_context = extended_context[line_buffer_last]
            elsif (extended_context[line_buffer[line_buffer.size-2]] && !line_buffer_first.eql?(extended_context[line_buffer[line_buffer.size-2]]))
              new_context = extended_context[line_buffer[line_buffer.size-2]]
            else
              new_context = extended_context[line_buffer_first.to_sym] unless line_buffer_first.nil? || line_buffer_first.empty?
            end
            active_context_copy.push_new_context(new_context, new_context) unless new_context.nil?
          end
        end

        return get_ac_candidates(active_context_copy, readline_input, invalid_context, goes_from_root, line_buffer_first||{})
      end

      # TODO: this is hack used this to hide 'node' context and use just node_identifier
      # we should rethink the design of shell context if we are about to use different behaviors like this
      def self.check_invisible_context(acc, entries, is_root, line_buffer=[], args=[])
        entries.reject! { |e| e.empty? }
        goes_from_root = args.first.start_with?('/')

        unless line_buffer.empty?
          command = line_buffer.split(' ').first
          current_c_name = acc.last_command_name
          current_context = acc.last_context
          clazz = DTK::Shell::Context.get_command_class(current_c_name)
          command_from_args = nil

          if args.first.include?('/')
            command_from_args = goes_from_root ? args.first.split('/')[1] : args.first.split('/').first
            clazz_from_args = DTK::Shell::Context.get_command_class(command_from_args) if command_from_args
          end

          # this delete-node is a hack because we need autocomplete when there is node with name 'node'
          if (command.eql?('cd') || command.eql?('cc') || command.eql?('popc') || command.eql?('pushc') || command.eql?('delete-node'))
            if is_root
              if entries.size >= 3
                node = entries[2]
                if (node && clazz_from_args.respond_to?(:valid_child?))
                  unless clazz_from_args.valid_children().first.to_s.include?(node)
                    entries[2] = ["node", node]
                    entries.flatten!
                  end
                end
              end
            else
              double_dots_count = DTK::Shell::ContextAux.count_double_dots(entries)

              unless double_dots_count > 0
                if clazz.respond_to?(:invisible_context)
                  if current_context.is_command?
                    node = entries[1]
                    if (node && clazz.respond_to?(:valid_child?))
                      unless clazz.valid_children().first.to_s.include?(node)
                        entries[1] = ["node", node]
                        entries.flatten!
                      end
                    end
                  elsif current_context.is_identifier?
                    node = entries[0]
                    if (node && clazz.respond_to?(:valid_child?))
                      unless clazz.valid_children().first.to_s.include?(node)
                        entries[0] = ["node", node]
                        entries.flatten!
                      end
                    end
                  end
                end
              end

            end
          end

        end

        entries
      end


      def prepare_context_change(args, active_context_copy, node_specific=nil, line_buffer=[], on_complete=false)
        # split original cc command
        entries = args.first.split(/\//)

        # transform alias to full path
        entries = Context.check_for_sym_link(entries) if root?
        entries = Context.check_invisible_context(active_context_copy, entries, root?, line_buffer, args)

        # if only '/' or just cc skip validation
        return active_context_copy if entries.empty?

        current_context_clazz, error_message, current_index = nil, nil, 0
        double_dots_count = DTK::Shell::ContextAux.count_double_dots(entries)

        # we remove '..' from our entries
        entries = entries.select { |e| !(e.empty? || DTK::Shell::ContextAux.is_double_dot?(e)) }

        # we go back in context based on '..'
        active_context_copy.pop_context(double_dots_count)

        # if cd .. back to node, skip node context and go to assembly/workspace context
        if (active_context_copy.last_context && entries)
          active_context_copy.pop_context(1) if (node_specific && active_context_copy.last_context.is_command? && active_context_copy.last_command_name.eql?("node") && on_complete)
        end

        # special case when using workspace context
        # if do cd .. from workspace/workspace identifier go directly to root not to workspace
        if active_context_copy.name_list.include?("workspace")
          count_workspaces = active_context_copy.name_list.inject(Hash.new(0)) {|h,i| h[i] += 1; h }
          active_context_copy.pop_context(1) if count_workspaces['workspace']==1
        end

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
          error_message, invalid_context = validate_command(clazz, current_context_clazz, command, active_context_copy)

          break if error_message
          # if we are dealing with new entries add them to active_context
          active_context_copy.push_new_context(command, command) if (i >= ac_size)
          current_context_clazz = clazz

          if value
            # context_hash_data is hash with :name, :identifier values
            context_hash_data, error_message, invalid_context = validate_value(command, value, active_context_copy)
            if error_message
              # hack: used just to avoid entering assembly/id/node or workspace/node context (remove when include this contexts again)
              if ((@active_context.last_context_name.eql?("node") || node_specific) && !@active_context.first_context_name().eql?("node") )
                active_context_copy.pop_context(1)
              end
              break
            end

            active_context_copy.push_new_context(context_hash_data[:name], command, context_hash_data[:identifier]) if ((i+1) >= ac_size)
          end
        end

        return active_context_copy, error_message, invalid_context
      end

      def validate_command(clazz, current_context_clazz, command, active_context_copy=nil)
        error_message = nil
        invalid_context = ""

        # if command class did not found or if command ends with '-'
        if (clazz.nil? || command.match(/-$/))
          error_message = "Context for '#{command}' could not be loaded.";
          invalid_context = command
        end

        # check if previous context support this one as a child
        unless current_context_clazz.nil?
          # valid child method is necessery to define parent-child relet.
          if current_context_clazz.respond_to?(:valid_child?)
            root_clazz = DTK::Shell::Context.get_command_class(active_context_copy.first_command_name)
            all_children = root_clazz.all_children() + root_clazz.valid_children()

            valid_all_children = (root_clazz != current_context_clazz) ? all_children.include?(command.to_sym) : true
            unless (current_context_clazz.valid_child?(command) && valid_all_children)

              error_message = "'#{command}' context is not valid."
              invalid_context = command

              if current_context_clazz.respond_to?(:invisible_context)
                ic = current_context_clazz.invisible_context()
                ic.each do |c|
                  if c.to_s.include?(command)
                    return nil, ""
                  end
                end
              end
            end
          else
            error_message = "'#{command}' context is not valid."
            invalid_context = command
          end
        end

        return error_message, invalid_context
      end


      # hack: used just to avoid entering assembly/id/node or workspace/node context (remove when include this contexts again)
      def is_restricted_context(first_c, args = [], tmp_active_context=nil)
        entries = args.first.split(/\//)
        invalid_context = ["workspace/node", "service/node"]
        double_dots_count = DTK::Shell::ContextAux.count_double_dots(entries)
        only_double_dots = entries.select{|e| !e.to_s.include?('..')}||[]
        back_flag = false

        last_from_current, message = nil, nil
        unless (root? || double_dots_count==0 || !only_double_dots.empty?)
          test_c = @previous_context
          test_c.pop_context(double_dots_count)
          last_from_current = test_c.last_context_name
          back_flag = true
        end

        unless args.empty?
          first_c ||= entries.first
          last_c = last_from_current||entries.last

          invalid_context.each do |ac|
            if ac.eql?("#{first_c}/#{last_c}")
              unless last_from_current
                last_1, last_2 = entries.last(2)
                if last_1.eql?(last_2)
                  args = entries.join('/')
                  return {:args => [args], :node_specific => true}
                end
              end
              message = "'#{last_c}' context is not valid."
              is_valid_id = check_for_id(first_c, last_c, tmp_active_context, args)

              # if ../ to node context, add one more .. to go to previous context (assembly/id or workspace)
              if back_flag
                message = nil
                entries << ".." if is_valid_id==false
              else
                if is_valid_id==false
                  entries.pop
                else
                  message = nil
                end
              end

              args = (entries.size<=1 ? entries : entries.join('/'))
              args = args.is_a?(Array) ? args : [args]
              if args.empty?
                raise DTK::Client::DtkValidationError, message
              else
                return {:args => args, :message => message, :node_specific => true}
              end

            end
          end
        end

        return {:args => args, :message => message}
      end

      def check_for_id(context, command, tmp_active_context, args)
        command_clazz = Context.get_command_class(context)
        invisible_context = command_clazz.respond_to?(:invisible_context) ? command_clazz.invisible_context.map { |e| e.to_s } : []
        entries = args.first.split(/\//)

        entries = Context.check_for_sym_link(entries) if root?
        unless invisible_context.empty?
          if root?
            tmp_active_context.push_new_context(entries[0], entries[0])
            context_hash_data, error_message, invalid_context = validate_value(entries[0], entries[1], tmp_active_context)

            return if error_message
            tmp_active_context.push_new_context(context_hash_data[:name], entries[0], context_hash_data[:identifier])
            context_hash_data, error_message, invalid_context = validate_value(command, command, tmp_active_context)

            return if error_message
            tmp_active_context.push_new_context(context_hash_data[:name], command, context_hash_data[:identifier])
          end


          node_ids = get_command_identifiers(invisible_context.first.to_s, tmp_active_context)
          node_names = node_ids ? node_ids.collect { |e| e[:name] } : []
        end

        return node_names.include?(command)
      end



      def validate_value(command, value, active_context_copy=nil)
        context_hash_data = nil
        invalid_context = ""
         # check value
        if value
          context_hash_data = valid_id?(command, value, nil, active_context_copy)
          unless context_hash_data
            error_message = "Identifier '#{value}' is not valid."
            # error_message = "Identifier '#{value}' for context '#{command}' is not valid";
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

        client_commands = CLIENT_COMMANDS
        client_commands.concat(DEV_COMMANDS) if DTK::Configuration.get(:development_mode)

        # we add client commands
        @current.concat(client_commands).sort!

        # holder for commands to be used since we do not want to remember all of them
        @context_commands = @current

        # we load thor command class identifiers for autocomplete context list
        command_context = get_command_identifiers(command_name)

        command_name_list = command_context ? command_context.collect { |e| e[:name] } : []
        @context_commands.concat(command_name_list) if current_command?

        # logic behind context loading
        #Readline.completer_word_break_characters=" "
        Readline.completion_proc = proc { |input| dynamic_autocomplete_context(input, Readline.respond_to?("line_buffer") ? Readline.line_buffer : [])}
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

      def current_alt_identifier?
        return @active_context.current_alt_identifier?
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

        return nil
      end

      def get_ac_candidates(active_context_copy, readline_input, invalid_context, goes_from_root, line_buffer=[])
        # helper indicator for case when there are more options in current context and cc command is not ended with '/'
        cutoff_forcely = false
        # input string segment used to filter results candidates
        results_filter = (readline_input.match(/\/$/) && invalid_context.empty?) ? "" : readline_input.split("/").last
        results_filter ||= ""

        command_clazz = Context.get_command_class(active_context_copy.last_command_name)
        extended_context_commands = nil

        unless command_clazz.nil?
          extended_context = command_clazz.respond_to?(:extended_context) ? command_clazz.extended_context() : {}

          unless extended_context.empty?
            extended_context = extended_context[:command]
            extended_context.reject!{|k,v| k.to_s!=line_buffer} if extended_context
            extended_context_commands = extended_context[line_buffer.to_sym] unless (line_buffer.empty? || extended_context.nil?)
          end
        end

        if extended_context_commands
            context_candidates = load_extended_context_commands(extended_context_commands, active_context_copy)
        else
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
        end

        # checking if results will contain context candidates based on input string segment
        context_candidates = context_candidates.grep( /^#{Regexp.escape(results_filter)}/ )

        # Show all context tasks if active context orignal and it's copy are on same context, and are not on root,
        # and if readline has one split result indicating user is not going trough n-level, but possibly executing a task
        task_candidates = []

        #task_candidates = @context_commands if (active_context_copy.last_context_name() == @active_context.last_context_name() && !active_context_copy.empty?)
        task_candidates = @context_commands if (active_context_copy.last_context_name() == @active_context.last_context_name() && !active_context_copy.empty? && readline_input.split("/").size <= 1)

        # create results object filtered by user input segment (results_filter)
        task_candidates = task_candidates.grep( /^#{Regexp.escape(results_filter)}/ )

        # autocomplete candidates are both context and task candidates; remove duplicates in results
        results = context_candidates

        # if command is 'cc/cd/pushc' displat only context candidates
        if line_buffer.empty?
          results += task_candidates
        else
          is_cc = line_buffer.split(' ')
          results += task_candidates unless (IDENTIFIERS_ONLY.include?(is_cc.first) || extended_context_commands)
        end

        # remove duplicate context or task candidates
        results.uniq!

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
        #return (results.size() == 1 && !context_candidates.empty?) ? (results.first + "/") : results
        return results

      end

      def get_ac_candidates_for_context(context, active_context_copy)
        # If last context is command, load all identifiers, otherwise, load next possible context command; if no contexts, load root tasks
        if context
          if context.is_command?
            command_identifiers   = get_command_identifiers(context.name, active_context_copy)
            n_level_ac_candidates = command_identifiers ? command_identifiers.collect { |e| e[:name] } : []
          else
            command_clazz         = Context.get_command_class(active_context_copy.last_command_name)
            root_clazz            = DTK::Shell::Context.get_command_class(active_context_copy.first_command_name)
            valid_all_children    = (root_clazz != command_clazz) ? (root_clazz.all_children() + root_clazz.valid_children()) : []
            n_level_ac_candidates = command_clazz.respond_to?(:valid_children) ? command_clazz.valid_children.map { |e| e.to_s } : []

            n_level_ac_candidates.select {|v| valid_all_children.include?(v.to_sym)} unless valid_all_children.empty?
            invisible_context = command_clazz.respond_to?(:invisible_context) ? command_clazz.invisible_context.map { |e| e.to_s } : []

            unless invisible_context.empty?
              node_ids = get_command_identifiers(invisible_context.first.to_s, active_context_copy)
              node_names = node_ids ? node_ids.collect { |e| e[:name] } : []

              n_level_ac_candidates.concat(node_names)
            end

            n_level_ac_candidates
          end
        else
          n_level_ac_candidates =  ROOT_TASKS
        end
      end

      # get class identifiers for given thor command, returns array of identifiers
      def get_command_identifiers(thor_command_name, active_context_copy=nil)
        begin
          command_clazz = Context.get_command_class(thor_command_name)

          if command_clazz && command_clazz.list_method_supported?
            # take just hashed arguemnts from multi return method
            hashed_args = get_command_parameters(thor_command_name, [], active_context_copy)[2]
            return command_clazz.get_identifiers(@conn, hashed_args)
          end
        rescue DTK::Client::DtkValidationError => e
          # TODO Check if handling needed. Error should happen only when autocomplete ID search illigal
        end

        return []
      end

      def load_extended_context_commands(extended_context_commands, active_context_copy)
        candidates = []
        entity_name = active_context_copy.last_context
        parent_entity = active_context_copy.context_list[1]

        if entity_name.is_identifier?
          endpoint = extended_context_commands[:endpoint]
          url = extended_context_commands[:url]
          opts = extended_context_commands[:opts]||{}

          if (parent_entity && parent_entity.is_identifier? && (parent_entity != entity_name))
            parent_id_label = "#{endpoint}_id".to_sym
            parent_id = parent_entity.identifier
            opts[parent_id_label] = parent_id
            id_label = "#{entity_name.entity}_id".to_sym
          end

          id_label ||= "#{endpoint}_id".to_sym
          id = entity_name.identifier
          opts[id_label] = id

          response_ruby_obj = DTK::Client::CommandBaseThor.get_cached_response(endpoint.to_sym, url, opts)
          return [] if(response_ruby_obj.nil? || !response_ruby_obj.ok?)

          response_ruby_obj.data.each do |d|
            candidates << d["display_name"]
          end
        end

        candidates
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
        clazz              = Context.get_command_class(entity_name)
        options            = Context.get_thor_options(clazz, method_name) unless clazz.nil?
        args, thor_options, invalid_options = Context.parse_thor_options(args, options)
        context_params.method_arguments = args


        unless available_tasks.include?(method_name)
          raise DTK::Client::DtkError, "Could not find task \"#{method_name}\"."
        end

        raise DTK::Client::DtkValidationError, "Option '#{invalid_options.first}' is not valid for current command!" unless invalid_options.empty?

        return entity_name, method_name, context_params, thor_options
      end

      #
      # We use enrich data to help when using dynamic_context loading, Readline.completition_proc
      # See bellow for more details
      #
      def get_command_parameters(cmd,args, active_context_copy=nil)
        # To support autocomplete feature, temp active context may be forwarded into method
        active_context_copy = @active_context unless active_context_copy

        entity_name, method_name, option_types = nil, nil, nil

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
        clazz = Context.get_command_class(entity_name)
        current_context_command = active_context_copy.last_command_name

        if ((current_context_command != entity_name) && !current_context_command.eql?("utils"))
          current_context_clazz = Context.get_command_class(current_context_command)
          options = Context.get_thor_options(current_context_clazz, cmd) if current_context_clazz
        else
          options = Context.get_thor_options(clazz, cmd) if clazz
        end

        # set rest of arguments as method options
        args, thor_options, invalid_options = Context.parse_thor_options(args, options)
        context_params.method_arguments = args

        return entity_name, method_name, context_params, thor_options, invalid_options
      end

      private

      #
      # method takes parameters that can hold specific thor options
      #
      def self.parse_thor_options(args, options=nil)
        type, invalid_options = nil, []

        # options to handle thor options -m MESSAGE and --list
        options_param_args = []
        args.each_with_index do |e,i|
          if (e.match(/^\-[a-zA-Z]?/) || e.match(/^\-\-/))
            type = Context.get_option_type(options, e) unless options.nil?
            if type.nil?
              options_param_args = nil
              invalid_options << e
              break
              # raise DTK::Client::DtkValidationError, "Option '#{e}' is not valid for current command!"
            else
              options_param_args << e
              options_param_args << args[i+1] unless type == :boolean
            end
          end
        end

        # remove thor_options but only once
        args = Client::CommonUtil.substract_array_once(args, options_param_args, true) unless options_param_args.nil?

        return args, options_param_args, invalid_options
      end

      def self.get_thor_options(clazz, command)
        command = command.gsub('-','_')
        options = nil
        options = clazz.all_tasks[command].options.collect{|k,v|{:alias=>v.aliases,:name=>v.name,:type=>v.type,:switch=>v.switch_name}} unless clazz.all_tasks[command].nil?

        return options
      end

      def self.get_option_type(options, option)
        @ret = nil

        options.each do |opt|
          @ret = opt[:type] if(opt[:alias].first == option || opt[:switch] == option)
        end

        return @ret
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

      # this file loads sessions history
      def self.load_session_history()
        unless is_there_history_file()
          puts "[INFO] History file is missing, shell history will be disabled. To enable it create file: '#{HISTORY_LOCATION}'"
          return []
        end

        content = File.open(HISTORY_LOCATION,'r').read
        return (content.empty? ? [] : JSON.parse(content))
      end

      def self.save_session_history(array_of_commands)
        return [] unless is_there_history_file()
        # we filter the list to remove neighbour duplicates
        filtered_commands = []
        array_of_commands.each_with_index do |a,i|
          filtered_commands << a if (a != array_of_commands[i+1] && is_allowed_command?(a))
        end

        # make sure we only save up to 'COMMAND_HISTORY_LIMIT' commands
        if filtered_commands.size > COMMAND_HISTORY_LIMIT
          filtered_commands = filtered_commands[-COMMAND_HISTORY_LIMIT,COMMAND_HISTORY_LIMIT+1]
        end

        File.open(HISTORY_LOCATION,'w') { |f| f.write(filtered_commands.to_json) }
      end

      private

      # list of commands that should be excluded from history
      EXCLUDE_COMMAND_LIST = ['create-provider','create-ec2-provider','create-physical-provider']

      def self.is_allowed_command?(full_command_entry)
        found = EXCLUDE_COMMAND_LIST.find { |cmd| full_command_entry.include?(cmd) }
        found.nil?
      end

      def self.is_there_history_file()
        unless File.exists? HISTORY_LOCATION
          begin
            File.open(HISTORY_LOCATION, 'w') {}
            return true
          rescue
            return false
          end
          #DtkLogger.instance.info "[INFO] Session shell history has been disabled, please create file '#{HISTORY_LOCATION}' to enable it."
        end
        return true
      end
    end
  end
end


