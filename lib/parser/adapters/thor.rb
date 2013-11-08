require 'thor'
require 'thor/group'
require 'readline'
require 'colorize'

dtk_require("../../shell/interactive_wizard")
dtk_require("../../util/os_util")
dtk_require("../../util/console")
dtk_require_common_commands('thor/task_status')
dtk_require_from_base("command_helper")
dtk_require("../../context_router")

module DTK
  module Client
    class CommandBaseThor < Thor
      dtk_nested_require('thor','common_option_defs')

      include CommandBase
      extend  CommandBase
      extend  TaskStatusMixin
      extend  Console
      include CommandHelperMixin
      extend CommonOptionDefsClassMixin

      @@cached_response = {}
      @@invalidate_map  = []
      TIME_DIFF         = 60   #second(s)
      EXTENDED_TIMEOUT  = 360  #second(s)

      # thor command specific constants
      ALT_IDENTIFIER_SEPARATOR = ':::'
      
      def initialize(args, opts, config)
        @conn = config[:conn]
        super
      end

      def self.execute_from_cli(conn,method_name,context_params,thor_options,shell_execution=false)
        @@shell_execution = shell_execution
        
        # I am sorry!
        if method_name == 'help'
          ret = start([method_name] + context_params.method_arguments,:conn => conn)      
        else
          ret = start([method_name, context_params] + (thor_options||[]),:conn => conn)
        end

        # special case where we have validation reply
        if ret.kind_of?(Response)
          if ret.validation_response?
            ret = action_on_revalidation_response(ret, conn, method_name, context_params, thor_options, shell_execution)
          end
        end

        ret.kind_of?(Response) ? ret : Response::NoOp.new
      end

      # TODO: Make sure that server responds with new format of ARGVS
      def self.action_on_revalidation_response(validation_response, conn, method_name, context_params, thor_options, shell_execution)
        puts "[NOTICE] #{validation_response.validation_message}"
        actions = validation_response.validation_actions

        actions.each_with_index do |action, i|
          if Console.confirmation_prompt("Pre-action '#{action['action']}' needed, execute"+"?")
            # we have hash map with values { :assembly_id => 2123123123, :option_1 => true }
            # we translate to array of values, with action as first element

            # def self.execute_from_cli(conn,method_name,context_params,options_args,shell_execution=false)
            response = self.execute_from_cli(conn, action['action'],  create_context_arguments(action['params']),[],shell_execution)
            # we abort if error happens
            ResponseErrorHandler.check(response)

            if action['wait_for_complete']
              entity_id, entity_type = action['wait_for_complete']['id'].to_s, action['wait_for_complete']['type']
              puts "Waiting for task to complete ..."
              task_status_aux(entity_id,entity_type,true)
            end
          else
            # validation action are being skipped
            return ""
          end
        end

        puts "Executing original action: '#{method_name}' ..."
        # if all executed correctly we run original action
        return self.execute_from_cli(conn,method_name, context_params,thor_options,shell_execution)
      end

      def self.invalidate_entities(*array_of_entites)
        #  we handle to cases here
        # n-context invalidation, whole structure
        @@invalidate_map << array_of_entites.join('_').to_sym

        # last entity
        @@invalidate_map << array_of_entites.last.to_sym
      end

      # we take current timestamp and compare it to timestamp stored in @@cached_response
      # if difference is greater than TIME_DIFF we send request again, if not we use
      # response from cache
      def self.get_cached_response(entity_name, url, subtype=nil)
        current_ts = Time.now.to_i
        # if @@cache_response is empty return true if not than return time difference between
        # current_ts and ts stored in cache
        time_difference = @@cached_response[entity_name].nil? ? true : ((current_ts - @@cached_response[entity_name][:ts]) > TIME_DIFF)         

        if (time_difference || @@invalidate_map.include?(entity_name))
          response = post rest_url(url), subtype

          # we do not want to catch is if it is not valid
          if response.nil? || response.empty?
            DtkLogger.instance.debug("Response was nil or empty for that reason we did not cache it.")
            return response
          end

          @@invalidate_map.delete(entity_name) if (@@invalidate_map.include?(entity_name) && response.ok?)                 
          @@cached_response.store(entity_name, {:response => response, :ts => current_ts}) if response.ok?
        end
        
        if @@cached_response[entity_name]
          return @@cached_response[entity_name][:response]
        else
          return nil
        end
      end

      def self.create_context_arguments(params)
        context_params = DTK::Shell::ContextParams.new
        params.each do |k,v|
          context_params.add_context_to_params(k,k,v)
        end
        return context_params
      end

      def self.list_method_supported?
        return (respond_to?(:validation_list) || respond_to?(:whoami))
      end

      # returns all task names for given thor class with use friendly names (with '-' instead '_')
      def self.task_names
        all_tasks().map(&:first).collect { |item| item.gsub('_','-')}
      end

      def self.get_usage_info(entity_name, method)
        # no need for nil checks since task will be found
        # [0] element contains desire usage description
        # [2] element contains method name with '_'
        result = printable_tasks().select { |help_item|  help_item[2].gsub('_','-') == method }.flatten[0]
        # we add entity name with dashes
        return result.gsub('dtk', "dtk #{entity_name.gsub('_','-')}")
      end

      # caches all the taks names for each possible tier and each thor class
      # returnes it, executes only once and only on dtk-shell start
      def self.tiered_task_names
        # cached data
        cached_tasks = {}

        # get command name from namespace (which is derived by thor from file name)
        command = namespace.split(':').last.gsub('_','-').upcase

        # first elvel identifier
        command_sym = command.downcase.to_sym
        command_id_sym = (command.downcase + '_wid').to_sym

        cached_tasks.store(command_sym, [])
        cached_tasks.store(command_id_sym, [])

        # n-context children
        all_children = []
        children = self.respond_to?(:all_children) ? self.all_children() : nil
        all_children << children unless children.nil?

        # some commands have utils subcontext which needs to be added to n-level
        utils_subcontext = self.respond_to?(:utils_subcontext) ? self.utils_subcontext() : nil
        all_children << utils_subcontext unless utils_subcontext.nil?

        # n-context-override task, special case which
        override_task_obj = self.respond_to?(:override_allowed_methods) ? self.override_allowed_methods.dup : nil

        # we seperate tier 1 and tier 2 tasks
        all_tasks().each do |task|
          # noralize task name with '-' since it will be displayed to user that way
          task_name = task[0].gsub('_','-')
          # we will match those commands that require identifiers (NAME/ID)
          # e.g. ASSEMBLY-NAME/ID list ...   => MATCH
          # e.g. [ASSEMBLY-NAME/ID] list ... => MATCH
          matched_data = task[1].usage.match(/\[?#{command}.?(NAME\/ID|ID\/NAME)\]?/)
          matched_alt_identifiers_data = nil

          # we chance alternate providers
          if respond_to?(:alternate_identifiers)
            alternate_identifiers = self.alternate_identifiers()

            alternate_identifiers.each do |a_provider|
              if matched_alt_identifiers_data = task[1].usage.match(/\[?#{a_provider}.?(NAME\/ID|ID\/NAME)\]?/)
                command_alt_sym = "#{command}_#{a_provider}".downcase.to_sym
                cached_tasks[command_alt_sym] = cached_tasks.fetch(command_alt_sym,[]) 
                cached_tasks[command_alt_sym] << task_name
                # when found break
                break
              end
            end
          end

          # only if not matched alt data found continue with caching of task
          unless matched_alt_identifiers_data
            if matched_data.nil?
              # no match it means it is tier 1 task, tier 1 => dtk:\assembly>
              cached_tasks[command_sym] << task_name
            else
              # match means it is tier 2 taks, tier 2 => dtk:\assembly\231312345>
              cached_tasks[command_id_sym] << task_name
              # if there are '[' it means it is optinal identifiers so it is tier 1 and tier 2 task
              cached_tasks[command_sym] << task_name if matched_data[0].include?('[')
            end
            
            # n-level matching
            all_children.each do |child|
              current_children = []

              child.each do |c|
                current_children << c.to_s

                # create entry e.g. assembly_node_id
                child_id_sym = (command.downcase + '_' + current_children.join('_') + '_wid').to_sym

                # n-context matching
                matched_data = task[1].usage.match(/\[?#{c.to_s.upcase}.?(NAME\/ID|ID\/NAME|ID|NAME)(\-?PATTERN)?\]?/)
                if matched_data
                  cached_tasks[child_id_sym] = cached_tasks.fetch(child_id_sym,[]) << task_name 
                end

                # override method list, we add these methods only once
                if override_task_obj && !override_task_obj.is_completed?(c)
                  command_o_tasks, identifier_o_tasks = override_task_obj.get_all_tasks(c)
                  child_sym    = (command.downcase + '_' + current_children.join('_')).to_sym

                  command_o_tasks.each do |o_task|
                    cached_tasks[child_sym] = cached_tasks.fetch(child_sym,[]) << o_task[0]
                  end

                  identifier_o_tasks.each do |o_task|
                    cached_tasks[child_id_sym] = cached_tasks.fetch(child_id_sym,[]) << o_task[0]
                  end

                  override_task_obj.add_to_completed(c)
                end
              end
            end

            # will leave this commented for now until we check if new code works properly
            # if children
            #   current_children = []
            #   children.each do |child|
            #     current_children << child.to_s

            #     # create entry e.g. assembly_node_id
            #     child_id_sym = (command.downcase + '_' + current_children.join('_') + '_wid').to_sym

            #     # n-context matching
            #     matched_data = task[1].usage.match(/\[?#{child.to_s.upcase}.?(NAME\/ID|ID\/NAME|ID|NAME)(\-?PATTERN)?\]?/)
            #     if matched_data
            #       cached_tasks[child_id_sym] = cached_tasks.fetch(child_id_sym,[]) << task_name 
            #     end

            #     # override method list, we add these methods only once
            #     if override_task_obj && !override_task_obj.is_completed?(child)
            #       command_o_tasks, identifier_o_tasks = override_task_obj.get_all_tasks(child)
            #       child_sym    = (command.downcase + '_' + current_children.join('_')).to_sym

            #       command_o_tasks.each do |o_task|
            #         cached_tasks[child_sym] = cached_tasks.fetch(child_sym,[]) << o_task[0]
            #       end

            #       identifier_o_tasks.each do |o_task|
            #         cached_tasks[child_id_sym] = cached_tasks.fetch(child_id_sym,[]) << o_task[0]
            #       end

            #       override_task_obj.add_to_completed(child)
            #     end
            #   end
            # end

          end
        end
        
        # there is always help, and in all cases this is exception to the rule
        cached_tasks[command_id_sym] << 'help'

        return cached_tasks
      end

      # we make valid methods to make sure that when context changing
      # we allow change only for valid ID/NAME
      def self.valid_id?(value, conn, context_params)

        context_list = self.get_identifiers(conn, context_params)
        results = context_list.select { |e| e[:name].eql?(value) || e[:identifier].eql?(value.to_i)}
        
        return results.empty? ? nil : results.first
      end

      def self.get_identifiers(conn, context_params)
        @conn    = conn if @conn.nil?
  
        # we force raw output
        # options = Thor::CoreExt::HashWithIndifferentAccess.new({'list' => true})

        3.downto(1) do
          # get list data from one of the methods             
          if respond_to?(:validation_list)
            response = validation_list(context_params)
          else
            clazz, endpoint, opts = whoami()
            response = get_cached_response(clazz, endpoint, opts)
          end

          unless (response.nil? || response.empty?)
            unless response['data'].nil?
              identifiers = []           
              response['data'].each do |element|
                identifiers << { :name => element['display_name'], :identifier => element['id'] }
              end
              return identifiers
            end          
          end
          unless response.nil?
            break if response["status"].eql?('ok')
          end
          sleep(1)
        end

        DtkLogger.instance.warn("[WARNING] We were not able to check cached context, possible errors may occur.")
        return []
      end

      no_tasks do

        ##
        # Block that allows users to specify part of the code which is expected to run for longer duration
        #
        def extended_timeout
          puts "Please wait, this could take a few minutes ..."
          old_timeout = ::DTK::Client::Conn.get_timeout()
          ::DTK::Client::Conn.set_timeout(EXTENDED_TIMEOUT)
          result = yield
          ::DTK::Client::Conn.set_timeout(old_timeout)
          result
        end

        # Method not implemented error
        def not_implemented
          raise DTK::Client::DtkError, "Method NOT IMPLEMENTED!"
        end

        def raise_validation_error_method_usage(method_name)
          usage_text = self.class.all_tasks[method_name][:usage]
          raise DTK::Client::DtkValidationError, "Invalid method usage, use: #{usage_text}"
        end

        # returns method name and usage
        def current_method_info
          return @_initializer[2][:current_task].name, @_initializer[2][:current_task].usage
        end

        # returns names of the arguments, after the method name
        def method_argument_names
          name, usage = current_method_info
          return usage.split(name.gsub(/_/,'-')).last.split(' ')
        end 

        #TODO: can make more efficient by having rest call that returns name from id, rather than using 'list path'
        #entity_id can be a name as well as an id
        def get_name_from_id_helper(entity_id, entity_type=nil,list_command_path=nil, subtype=nil)
          return entity_id unless is_numeric_id?(entity_id)

          entity_id = entity_id.to_i
          if entity_type.nil?
            entity_type,list_command_path,subtype = self.class.whoami()
          end

          match = nil
          response = self.class.get_cached_response(entity_type,list_command_path,subtype)
          if response.ok? and response['data']
            match = response['data'].find{|entity|entity_id == entity['id']}
          end
          unless match
            raise DTK::Client::DtkError, "Not able to resolve entity name, please provide #{entity_type} name." 
          end
          match['display_name']
        end

        def is_numeric_id?(possible_id)             
          !possible_id.to_s.match(/^[0-9]+$/).nil?
        end

        # User input prompt
        def user_input(message)
          trap("INT", "SIG_IGN")
          while line = Readline.readline("#{message}: ",true)
            unless line.chomp.empty?
              trap("INT", false)
              return line
            end
          end          
        end
        
        def get_type_and_raise_error_if_invalid(about, default_about, type_options)
          about ||= default_about
          raise DTK::Client::DtkError, "Not supported type '#{about}' for list for current context level. Possible type options: #{type_options.join(', ')}" unless type_options.include?(about)
          return about, about[0..-2].to_sym
        end

        # check for delimiter '/', if present returns namespace and name for module/service
        # returns: namespace, name
        def get_namespace_and_name(input_remote_name)
          (input_remote_name||'').include?('/') ? input_remote_name.split('/') : [nil, input_remote_name]
        end
      end


      ##
      # This is fix where we wanna exclude basename print when using dtk-shell.
      # Thor has banner method, representing row when help is invoked. As such banner
      # will print out basename first. e.g.
      #
      # dtk-shell assembly list [library|target]         # List asssemblies in library or target
      #
      # Basename is derived from name of file, as such can be overriden to serve some other
      # logic.
      #
      def self.basename
        basename = super
        basename = '' if basename == 'dtk-shell'
        return basename
      end

      desc "help [SUBCOMMAND]", "Describes available subcommands or one specific subcommand"
      def help(*args)
        puts # pretty print
        not_dtk_clazz = true
        
        if defined?(DTK::Client::Dtk)
          not_dtk_clazz = !self.class.eql?(DTK::Client::Dtk)
        end

        # not_dtk_clazz - we don't use subcommand print in case of root DTK class
        # for other classes Assembly, Node, etc. we print subcommand
        # this gives us console output: dtk assembly converge ASSEMBLY-ID
        #
        # @@shell_execution - if we run from shell we don't want subcommand output
        #

        super(args.empty? ? nil : args.first, not_dtk_clazz && !@@shell_execution)

        # we will print error in case configuration has reported error
        @conn.print_warning if @conn.connection_error?
        puts # pretty print
      end
    end
  end
end
