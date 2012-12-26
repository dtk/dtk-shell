require 'thor'
require 'thor/group'
require 'readline'
require 'colorize'

dtk_require("../../shell/interactive_wizard")
dtk_require("../../util/os_util")
dtk_require("../../util/console")
dtk_require_common_commands('thor/task_status')


module DTK
  module Client
    class CommandBaseThor < Thor
      include CommandBase
      extend  CommandBase
      extend  TaskStatusMixin
      extend  Console

      @@cached_response = {}
      @@invalidate_map  = []
      TIME_DIFF         = 60  #second(s)

      
      def initialize(args, opts, config)
        @conn = config[:conn]
        super
      end

      def self.execute_from_cli(conn,argv,shell_execution=false)
        @@shell_execution = shell_execution
        ret = start(arg_analyzer(argv),:conn => conn)

        # special case where we have validation reply
        if ret.kind_of?(Response)
          if ret.validation_response?
            ret = action_on_revalidation_response(ret, conn, argv, shell_execution)
          end
        end

        ret.kind_of?(Response) ? ret : Response::NoOp.new
      end

      def self.action_on_revalidation_response(validation_response, conn, argv, shell_execution)
        puts "[NOTICE] #{validation_response.validation_message}"
        actions = validation_response.validation_actions

        actions.each_with_index do |action, i|
          if Console.confirmation_prompt("Pre-action '#{action['action']}' neeeded, execute?")
            # we have hash map with values { :assembly_id => 2123123123, :option_1 => true }
            # we translate to array of values, with action as first element
            method_args = action['params'].values.unshift(action['action'])
            response = self.execute_from_cli(conn, method_args, shell_execution)
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

        puts "Executing original action: '#{argv.reverse.join('/')}' ..."
        # if all executed correctly we run original action
        return self.execute_from_cli(conn, argv, shell_execution)
      end

      # Method will check if there ID/Name before one of the commands if so
      # it will route it properly by placing ID as last param
      def self.arg_analyzer(argv)
        all_task_names = task_names()
        # we are looking for case when task name is second options and ID/NAME is first
        unless argv.first == 'help'
          if (argv.size > 1 && all_task_names.include?(argv[1]))

            # check if required params have been met, see UnboundMethod#arity
            method_definition = self.instance_method(argv[1].gsub('-','_').to_sym)

            # if negative it means that it has optional parameters, required number is negative value + 1
            required_params = (method_definition.arity < 0) ? method_definition.arity+1 : method_definition.arity

            # number 1 indicates here TASK NAME
            if (argv.size < required_params + 1)
              raise DTK::Client::DtkError, "Method 'dtk #{argv[1]}' requires at least #{required_params-argv.size} argument."
            end
            
            # first element goes on the end
            argv << argv.shift
          end
        end
        
        # if task name is not in first place, switch arguments positions
        argv << argv.shift unless (all_task_names.include?(argv[0]) || argv.empty?)

        argv
      end

      # we take current timestamp and compare it to timestamp stored in @@cached_response
      # if difference is greater than TIME_DIFF we send request again, if not we use
      # response from cache
      def self.get_cached_response(clazz, url, subtype=nil)
        current_ts = Time.now.to_i
        # if @@cache_response is empty return true if not than return time difference between
        # current_ts and ts stored in cache
        time_difference = @@cached_response[clazz].nil? ? true : ((current_ts - @@cached_response[clazz][:ts]) > TIME_DIFF)
        
        if (time_difference || @@invalidate_map.include?(clazz))
          response = post rest_url(url), subtype
          # we do not want to catch is if it is not valid
          if response.nil? || response.empty?
            DtkLogger.instance.debug("Response was nil or empty for that reason we did not cache it.")
            return response
          end

          @@invalidate_map.delete(clazz) if (@@invalidate_map.include?(clazz) && response["status"].eql?('ok'))
          @@cached_response.store(clazz, {:response => response, :ts => current_ts})
        end

        return @@cached_response[clazz][:response]
      end

      # returns all task names for given thor class with use friendly names (with '-' instead '_')
      def self.task_names     
        task_names = all_tasks().map(&:first).collect { |item| item.gsub('_','-')}
      end

      # returns 2 arrays, with tier 1 tasks and tier 2 tasks
      def self.tiered_task_names
        # containers for tier 1/2 command list of tasks (or contexts)
        tier_1,tier_2 = [], []
        # get command name from namespace (which is derived by thor from file name)
        command = namespace.split(':').last.gsub('_','-').upcase

        # we seperate tier 1 and tier 2 tasks
        all_tasks().each do |task|
          # noralize task name with '-' since it will be displayed to user that way
          task_name = task[0].gsub('_','-')
          # we will match those commands that require identifiers (NAME/ID)
          # e.g. ASSEMBLY-NAME/ID list ...   => MATCH
          # e.g. [ASSEMBLY-NAME/ID] list ... => MATCH
          matched_data = task[1].usage.match(/\[?#{command}.?(NAME\/ID|ID\/NAME)\]?/)
          if matched_data.nil?
            # no match it means it is tier 1 task, tier 1 => dtk:\assembly>
            tier_1 << task_name
          else
            # match means it is tier 2 taks, tier 2 => dtk:\assembly\231312345>
            tier_2 << task_name
            # if there are '[' it means it is optinal identifiers so it is tier 1 and tier 2 task
            tier_1 << task_name if matched_data[0].include?('[')
          end
        end
        # there is always help, and in all cases this is exception to the rule
        tier_2 << 'help'

        return tier_1.sort, tier_2.sort
      end

      # we make valid methods to make sure that when context changing
      # we allow change only for valid ID/NAME
      def self.valid_id?(value, conn)
        @conn    = conn if @conn.nil?
        clazz, endpoint, subtype = whoami()

        3.downto(1) do
          response = get_cached_response(clazz, endpoint, subtype)
          unless (response.nil? || response.empty? || response['data'].nil?)
            response['data'].each do |element|
              return true if (element['id'].to_s==value || element['display_name'].to_s==value)
            end
            return false
          end

          break if response["status"].eql?('ok')
          sleep(1)
        end

        DtkLogger.instance.warn("[WARNING] We were not able to check cached context, possible errors may occur.")
        return true
      end

      def self.get_identifiers(conn)
        @conn    = conn if @conn.nil?
        clazz, endpoint, subtype = whoami()

        3.downto(1) do
          response = get_cached_response(clazz, endpoint, subtype)
          unless (response.nil? || response.empty?)
            unless response['data'].nil?
              identifiers = []
              response['data'].each do |element|
                 identifiers << element['display_name']
              end
              return identifiers
            end          
          end

          break if response["status"].eql?('ok')
          sleep(1)
        end

        DtkLogger.instance.warn("[WARNING] We were not able to check cached context, possible errors may occur.")
        return []
      end

      no_tasks do
        # Method not implemented error
        def not_implemented
          raise DTK::Client::DtkError, "Method NOT IMPLEMENTED!"
        end

        def is_numeric_id?(possible_id)             
          return !possible_id.match(/^[0-9]+$/).nil?
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

        ##
        # SHARED CODE - CODE SHARED BETWEEN 2 or more COMMAND ENTITIES
        ##
        # ASSEMBLY & NODE CODE
        ## 
        def assembly_start(assembly_id, node_pattern_filter)             

          post_body = {
            :assembly_id  => assembly_id,
            :node_pattern => node_pattern_filter
          }

          # we expect action result ID
          response = post rest_url("assembly/start"), post_body
          return response  if response.data(:errors)

          action_result_id = response.data(:action_results_id)

          # bigger number here due to possibilty of multiple nodes
          # taking too much time to be ready
          18.times do
            action_body = {
              :action_results_id => action_result_id,
              :using_simple_queue      => true
            }
            response = post(rest_url("assembly/get_action_results"),action_body)

            if response['errors']
              return response
            end

            break unless response.data(:result).nil?

            puts "Waiting for nodes to be ready ..."
            sleep(10)
          end

          if response.data(:result).nil?
            raise DTK::Client::DtkError, "Server seems to be taking too long to start node(s)."
          end

          task_id = response.data(:result)['task_id']
          post(rest_url("task/execute"), "task_id" => task_id)
        end

        def assembly_stop(assembly_id, node_pattern_filter)
          post_body = {
            :assembly_id => assembly_id,
            :node_pattern => node_pattern_filter
          }

          post rest_url("assembly/stop"), post_body
        end

        ##
        # SHARED CODE - CODE END
        ##
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
        super(args.empty? ? nil : args, not_dtk_clazz && !@@shell_execution)

        # we will print error in case configuration has reported error
        @conn.print_warning if @conn.connection_error?
      end
    end
  end
end
