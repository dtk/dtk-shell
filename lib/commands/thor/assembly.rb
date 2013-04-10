require 'rest_client'
require 'json'
require 'colorize'
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_common_commands('thor/task_status')
dtk_require_common_commands('thor/set_required_params')

LOG_SLEEP_TIME   = Config::Configuration.get(:tail_log_frequency)
DEBUG_SLEEP_TIME = Config::Configuration.get(:debug_task_frequency)

# regex: (context_params.retrieve_arguments\([a-z\[\]:_,0-9!]+)
# replace: $1,method_argument_names

module DTK::Client
  class Assembly < CommandBaseThor

    no_tasks do
      include TaskStatusMixin
      include SetRequiredParamsMixin
    end

    def self.pretty_print_cols()
      PPColumns.get(:assembly)
    end

    def self.valid_children()
      [:node]
    end

    # this includes children of children
    def self.all_children()
      [:node, :component, :attribute]
    end

    def self.valid_child?(name_of_sub_context)
      return Assembly.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      response = get_cached_response(:assembly, "assembly/list", {:subtype  => 'instance'})
      return response
    end

    # TODO: Hack which is necessery for the specific problem (DTK-541), something to reconsider down the line
    # at this point not sure what would be clenear solution

    # :all             => include both for commands with command and identifier
    # :command_only    => only on command level
    # :identifier_only => only on identifier level for given entity (command)
    #
    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :all => {
          :node      => [
            ['list',"list [FILTER] [--list] ","# List nodes"],
            ['list-components',"list-components [FILTER] [--list] ","# List components associated with assembly's node."],
            ['list-attributes',"list-attributes [FILTER] [--list] ","# List attributes associated with assembly's node."]
          ],
          :component => [
            ['list',"list [FILTER] [--list] ","# List components."],
            ['list-attributes',"list-attributes [FILTER] [--list] ","# List attributes associated with given component."]
          ]
        },
        :command_only => {
          :attribute => [
            ['list',"list [attributes] [FILTER] [--list] ","# List attributess."]
          ]
        },
        :identifier_only => {
          :node      => [
            ['info',"info","# Return info about node instance belonging to given assembly."],
            ['get-netstats',"get-netstats","# Returns getnetstats for given node instance belonging to context assembly."],
            ['get-ps', "get-ps", "# Returns a list of running processes for a given node instance belonging to context assembly."]
          ],
          :component => [
            ['info',"info","# Return info about component instance belonging to given node."]
          ],
          :attribute => [
            ['info',"info","# Return info about attribute instance belonging to given component."]
          ]
        }
      })
    end

    desc "ASSEMBLY-NAME/ID start [NODE-ID-PATTERN]", "Starts all assembly's nodes,  specific nodes can be selected via node id regex."
    def start(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [:assembly_id!,:node_id]
      else
        mapping = [:assembly_id!,:option_1]
      end

      assembly_id, node_pattern = context_params.retrieve_arguments(mapping,method_argument_names)

      assembly_start(assembly_id, node_pattern)
    end

    desc "ASSEMBLY-NAME/ID stop [NODE-ID-PATTERN]", "Stops all assembly's nodes, specific nodes can be selected via node id regex."
    def stop(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [:assembly_id!,:node_id]
      else
        mapping = [:assembly_id!,:option_1]
      end

      assembly_id, node_pattern = context_params.retrieve_arguments(mapping,method_argument_names)

      assembly_stop(assembly_id, node_pattern)
    end

    desc "ASSEMBLY-NAME/ID cancel-task TASK_ID", "Cancels task."
    def cancel_task(context_params)
      task_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      response = post rest_url("task/cancel_task"), { :task_id => task_id }
    end

    desc "ASSEMBLY-NAME/ID create-new-template SERVICE-MODULE-NAME ASSEMBLY-TEMPLATE-NAME", "Create a new assembly template from workspace assembly" 
    def create_new_template(context_params)        
      assembly_id, service_module_name, assembly_template_name = context_params.retrieve_arguments([:assembly_id!,:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => assembly_id,
        :service_module_name => service_module_name,
        :assembly_template_name => assembly_template_name
      }
      response = post rest_url("assembly/create_new_template"), post_body
      # when changing context send request for getting latest assembly_templates instead of getting from cache
      @@invalidate_map << :assembly_template

      return response
    end
    
    desc "ASSEMBLY-NAME/ID find-violations", "Finds violations in assembly that will prevent a converge operation"
    def find_violations(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)
      response = post rest_url("assembly/find_violations"),:assembly_id => assembly_id
      response.render_table(:violation)
    end
    
    desc "ASSEMBLY-NAME/ID converge [-m COMMIT-MSG]", "Converges assembly instance"
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def converge(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)

      post_body = {
        :assembly_id => assembly_id
      }

      response = post rest_url("assembly/find_violations"), post_body
      return response unless response.ok?
      if response.data and response.data.size > 0
        #TODO: may not directly print here; isntead use a lower level fn
        puts "The following violations were found; they must be corrected before the assembly can be converged".colorize(:red)
        return response.render_table(:violation)
      end

      post_body.merge!(:commit_msg => options.commit_msg) if options.commit_msg

      response = post rest_url("assembly/create_task"), post_body
      return response unless response.ok?

      # execute task
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

=begin
TODO: will put in dot release and will rename to 'extend'
    desc "ASSEMBLY-NAME/ID add EXTENSION-TYPE [-n COUNT]", "Adds a sub assembly template to the assembly"
    method_option "count",:aliases => "-n" ,
      :type => :string, #integer 
      :banner => "COUNT",
      :desc => "Number of sub-assemblies to add"
    def add_node(context_params)
      assembly_id,service_add_on_name = context_params.retrieve_arguments([:assembly_id!,:option_1!],method_argument_names)

      # create task
      post_body = {
        :assembly_id => assembly_id,
        :service_add_on_name => service_add_on_name
      }

      post_body.merge!(:count => options.count) if options.count

      response = post rest_url("assembly/add__service_add_on"), post_body
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly

      return response
    end

    desc "ASSEMBLY-NAME/ID possible-extensions", "Lists the possible extensions to the assembly" 
    def possible_extensions(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)

      post_body = {
        :assembly_id => assembly_id
      }
      response = post(rest_url("assembly/list_possible_add_ons"),post_body)
      response.render_table(:service_add_on)
    end
=end

    desc "ASSEMBLY-NAME/ID task-status [--wait]", "Task status of running or last assembly task"
    method_option :wait, :type => :boolean, :default => false
    def task_status(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)
      task_status_aux(assembly_id,:assembly,options.wait?)
    end

    desc "ASSEMBLY-NAME/ID run-smoketests", "Run smoketests associated with assembly instance"
    def run_smoketests(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)
      post_body = {
        :assembly_id => assembly_id
      }
      # create smoke test
      response = post rest_url("assembly/create_smoketests_task"), post_body
      return response unless response.ok?
      # execute
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "ASSEMBLY-NAME/ID list-nodes [FILTER] [--list] ","List nodes associated with assembly."
    method_option :list, :type => :boolean, :default => false
    def list_nodes(context_params)
      context_params.method_arguments = ["nodes"]
      list(context_params)
    end

    desc "ASSEMBLY-NAME/ID list-components [FILTER] [--list] ","List components associated with assembly."
    method_option :list, :type => :boolean, :default => false
    def list_components(context_params)
      context_params.method_arguments = ["components"]
      list(context_params)
    end

    desc "ASSEMBLY-NAME/ID list-attributes [FILTER] [--list] ","List attributes associated with assembly."
    method_option :list, :type => :boolean, :default => false
    def list_attributes(context_params)
      context_params.method_arguments = ["attributes"]
      list(context_params)
    end

    desc "ASSEMBLY-NAME/ID list-tasks [FILTER] [--list] ","List tasks associated with assembly."
    method_option :list, :type => :boolean, :default => false
    def list_tasks(context_params)
      context_params.method_arguments = ["tasks"]
      list(context_params)
    end

    #TODO: put in flag to control detail level
    desc "[ASSEMBLY-NAME/ID] list [FILTER] [--list] ","List assemblies."
    method_option :list, :type => :boolean, :default => false
    def list(context_params)
      assembly_id, node_id, component_id, attribute_id, about, filter = context_params.retrieve_arguments([:assembly_id,:node_id,:component_id,:attribute_id,:option_1,:option_2],method_argument_names)
      
      if about
        case about
          when "nodes":
            data_type = :node
          when "components":
            data_type = :component
          when "attributes":
            data_type = :attribute
          when "tasks":
            data_type = :task
          else
            raise_validation_error_method_usage('list')
        end 
      end

      post_body = {
        :assembly_id => assembly_id,
        :node_id => node_id,
        :component_id => component_id,
        :subtype     => 'instance',
        :filter      => filter
      }
      rest_endpoint = "assembly/info_about"

      if context_params.is_last_command_eql_to?(:attribute)
        
        raise DTK::Client::DtkError, "Not supported command for current context level." if attribute_id
        about, data_type = get_type_and_raise_error_if_invalid(about, "attributes", ["attributes"])

      elsif context_params.is_last_command_eql_to?(:component)
        
        if component_id
          about, data_type = get_type_and_raise_error_if_invalid(about, "attributes", ["attributes"])
        else
          about, data_type = get_type_and_raise_error_if_invalid(about, "components", ["attributes", "components"])
        end

      elsif context_params.is_last_command_eql_to?(:node)

        if node_id
          about, data_type = get_type_and_raise_error_if_invalid(about, "components", ["attributes", "components"])
        else
          about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes"])
        end

      else

        if assembly_id
          about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes", "tasks"])
        else
          data_type = :assembly
          post_body = { :subtype  => 'instance', :detail_level => 'nodes' }
          rest_endpoint = "assembly/list"
        end
          
      end

      post_body[:about] = about
      response = post rest_url(rest_endpoint), post_body
      
      # set render view to be used
      response.render_table(data_type) unless options.list?

      return response
      
    end

    desc "ASSEMBLY-NAME/ID add-connection CONN-TYPE SERVICE-REF1/ID SERVICE-REF2/ID", "Add a connection between two services in an assembly"
    def add_connection(context_params)
      assembly_id,conn_type,sr1,sr2 = context_params.retrieve_arguments([:assembly_id!,:option_1!,:option_2!,:option_3!],method_argument_names)
      post_body = {
        :assembly_id => assembly_id,
        :connection_type => conn_type,
        :input_service_ref_id => sr1,
        :output_service_ref_id => sr2
      }
      post rest_url("assembly/add_connection"), post_body
    end

    desc "ASSEMBLY-NAME/ID list-connections [--missing | --possible]","List connections between services on asssembly"
    method_option "missing",:aliases => "-m" ,
      :type => :boolean,
      :desc => "List missing connections"
    method_option "possible",:aliases => "-p" ,
      :type => :boolean,
      :desc => "List possible connections"
    def list_connections(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)

      post_body = {
        :assembly_id => assembly_id
      }
      #TODO: make sure that dont have both missing and possible true at same time
      data_type = :service_connection 
      if options.missing?
        post_body.merge!(:find_missing => true) if options.missing?
        data_type = :service_ref
      elsif options.possible?
        data_type = :possible_service_connection
        post_body.merge!(:find_possible => true) if options.possible?
      end

      response = post rest_url("assembly/list_connections"), post_body
      response.render_table(data_type)
    end

    desc "ASSEMBLY-NAME/ID list-smoketests","List smoketests on asssembly"
    def list_smoketests(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)

      post_body = {
        :assembly_id => assembly_id
      }
      post rest_url("assembly/list_smoketests"), post_body
    end

    desc "ASSEMBLY-NAME/ID info", "Return info about assembly instance identified by name/id"
    def info(context_params)
      assembly_id, node_id, component_id, attribute_id = context_params.retrieve_arguments([:assembly_id!, :node_id, :component_id, :attribute_id],method_argument_names)
 
      post_body = {
        :assembly_id => assembly_id,
        :node_id     => node_id,
        :component_id => component_id,
        :attribute_id => attribute_id,
        :subtype     => :instance
      }
      post rest_url("assembly/info"), post_body
    end

    desc "delete-and-destroy ASSEMBLY-NODE/ID -y", "Delete assembly instance, terminating any nodes that have been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_and_destroy(context_params)
      assembly_id = context_params.retrieve_arguments([:option_1!],method_argument_names)

      unless options.force?
        # Ask user if really want to delete assembly, if not then return to dtk-shell without deleting
        #used form "+'?' because ?" confused emacs ruby rendering
        what = "assembly"
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy #{what} '#{assembly_id}' and its nodes"+'?')
      end

      post_body = {
        :assembly_id => assembly_id,
        :subtype => :instance
      }

      response = post rest_url("assembly/delete"), post_body
         
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly
      return response
    end

    desc "ASSEMBLY-NAME/ID set ATTRIBUTE-NAME/ID VALUE", "Set target assembly attributes"
    def set(context_params)

      if context_params.is_there_identifier?(:attribute)
        mapping = [:assembly_id!,:attribute_id!, :option_1!]
      else
        mapping = [:assembly_id!,:option_1!,:option_2!]
      end

      # TODO 
      # for node level add node restriction, so attributes are set just for node in active context
      # add restriction for attribute-pattern at component level (display attributes just for that component)
      # same restricton is needed for attribute level, but than only value is provided by the user

      assembly_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)

      post_body = {
        :assembly_id => assembly_id,
        :pattern => pattern,
        :value => value
      }
      #TODO: have this return format like assembly show attributes with subset of rows that gt changed
      post rest_url("assembly/set_attributes"), post_body
    end

    desc "create-jenkins-project ASSEMBLY-TEMPLATE-NAME/ID", "Create Jenkins project for assembly template"
    def create_jenkins_project(context_params)
      assembly_id  = context_params.retrieve_arguments([:option_1!],method_argument_names)
      #require put here so dont necessarily have to install jenkins client gems
      dtk_require_from_base('command_helpers/jenkins_client')
      post_body = {
        :assembly_id => assembly_id,
        :subtype => :template
      }
      response = post(rest_url("assembly/info"),post_body)
      return response unless response.ok?
      assembly_id,assembly_name = response.data(:id,:display_name)
      #TODO: modify JenkinsClient to use response wrapper
      JenkinsClient.create_assembly_project?(assembly_name,assembly_id)
      nil
    end

#TODO: in adot release addd auto-compleet capability
#    desc "ASSEMBLY-NAME/ID add-assembly ASSEMBLY-TEMPLATE-NAME/ID [--auto-complete]", "Add (stage) an assembly template to become part of this assembly instance"
    desc "ASSEMBLY-NAME/ID add-assembly ASSEMBLY-TEMPLATE-NAME/ID", "Add (stage) an assembly template to become part of this assembly instance"
    method_option "auto-complete",:aliases => "-a" ,
      :type => :boolean, 
      :default=> false,
      :desc => "Automatically add in connections"
    def add_assembly(context_params)
      assembly_id,assembly_template_id = context_params.retrieve_arguments([:assembly_id,:option_1!],method_argument_names)
      post_body = {
        :assembly_id => assembly_id,
        :assembly_template_id => assembly_template_id
      }
      post_body.merge!(:auto_add_connections => true) if options.auto_complete?
      post rest_url("assembly/add_assembly_template"), post_body
    end

    desc "ASSEMBLY-NAME/ID add-node ASSEMBLY-NODES-NAME [-n NODE-TEMPLATE-ID]", "Add (stage) a new node to the assembly"
    method_option "node_template_id",:aliases => "-n" ,
      :type => :string, 
      :banner => "NODE-TEMPLATE-ID",
      :desc => "Node Template id"
    def add_node(context_params)
      assembly_id,assembly_node_name = context_params.retrieve_arguments([:assembly_id,:option_1!],method_argument_names)
      post_body = {
        :assembly_id => assembly_id,
        :assembly_node_name => assembly_node_name
      }
      post_body.merge!(:node_template_id => options["node_template_id"]) if options["node_template_id"]

      post rest_url("assembly/add_node"), post_body
    end

    desc "ASSEMBLY-NAME/ID add-component NODE-ID COMPONENT-TEMPLATE-NAME/ID [DEPENDENCY-ORDER-INDEX]", "Add component template to assembly node. Without order index default order location is on the end."
    def add_component(context_params)
    
      # If method is invoked from 'assembly/node' level retrieve node_id argument 
      # directly from active context
      if context_params.is_there_identifier?(:node)
        mapping = [:assembly_id!,:node_id!,:option_1!,:option_2]
      else
        # otherwise retrieve node_id from command options
        mapping = [:assembly_id!,:option_1!,:option_2!,:option_3]
      end

      assembly_id,node_id,component_template_id,order_index = context_params.retrieve_arguments(mapping,method_argument_names)

      post_body = {
        :assembly_id => assembly_id,
        :node_id => node_id,
        :component_template_id => component_template_id,
        :order_index => order_index
      }

      post rest_url("assembly/add_component"), post_body
    end

    desc "ASSEMBLY-NAME/ID delete-component COMPONENT-ID","Delete component from assembly"
    def delete_component(context_params)
      assembly_id, node_id, component_id = context_params.retrieve_arguments([:assembly_id!,:node_id,:option_1!],method_argument_names)

      post_body = {
        :assembly_id => assembly_id,
        :node_id => node_id,
        :component_id => component_id
      }
      response = post(rest_url("assembly/delete_component"),post_body)
    end


    desc "ASSEMBLY-NAME/ID get-netstats", "Get netstats"
    def get_netstats(context_params)
      assembly_id,node_id = context_params.retrieve_arguments([:assembly_id!,:node_id],method_argument_names)

      post_body = {
        :assembly_id => assembly_id,
        :node_id => node_id
      }  

      response = post(rest_url("assembly/initiate_get_netstats"),post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => false
        }
        response = post(rest_url("assembly/get_action_results"),post_body)
        count += 1
        if count > GetNetStatsTries or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == GetNetStatsTries
            ret_only_if_complete = false
          end
          sleep GetNetStatsSleep
        end
      end

      require 'ap'
      ap response

      #TODO: needed better way to render what is one of teh feileds which is any array (:results in this case)
      response.set_data(*response.data(:results))
      response.render_table(:netstat_data)
    end
    GetNetStatsTries = 6
    GetNetStatsSleep = 0.5

    desc "ASSEMBLY-NAME/ID get-ps", "Get ps"
    def get_ps(context_params)
      assembly_id,node_id = context_params.retrieve_arguments([:assembly_id!,:node_id],method_argument_names)

      post_body = {
        :assembly_id => assembly_id,
        :node_id => node_id
      }  

      response = post(rest_url("assembly/initiate_get_ps"),post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => true
        }
        response = post(rest_url("assembly/get_action_results"),post_body)
        count += 1
        if count > GetPsTries or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == GetPsTries
            ret_only_if_complete = false
          end
          sleep GetPsSleep
        end
      end

      #TODO: needed better way to render what is one of teh feileds which is any array (:results in this case)
      response.set_data(*response.data['results'].values.flatten)
      response.render_table(:ps_data)
    end
    GetPsTries = 6
    GetPsSleep = 0.5

    desc "ASSEMBLY-NAME/ID set-required-params", "Interactive dialog to set required params that are not currently set"
    def set_required_params(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)
      set_required_params_aux(assembly_id,:assembly,:instance)
    end

    desc "ASSEMBLY-NAME/ID tail NODE-ID LOG-PATH [REGEX-PATTERN] [--more]","Tail specified number of lines from log"
    method_option :more, :type => :boolean, :default => false
    def tail(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [:assembly_id!,:node_id!,:option_1!,:option_2]
      else
        mapping = [:assembly_id!,:option_1!,:option_2!,:option_3]
      end
      
      assembly_id,node_identifier,log_path,grep_option = context_params.retrieve_arguments(mapping,method_argument_names)
     
      last_line = nil
      begin

        file_path = File.join('/tmp',"dtk_tail_#{Time.now.to_i}.tmp")
        tail_temp_file = File.open(file_path,"a")

        file_ready = false

        t1 = Thread.new do
          while true
            post_body = {
              :assembly_id     => assembly_id,
              :subtype         => 'instance',
              :start_line      => last_line,
              :node_identifier => node_identifier,
              :log_path        => log_path,
              :grep_option     => grep_option
            }

            response = post rest_url("assembly/initiate_get_log"), post_body

            unless response.ok?
              raise DTK::Client::DtkError, "Error while getting log from server, there was no successful response."
            end

            action_results_id = response.data(:action_results_id)
            action_body = {
              :action_results_id => action_results_id,
              :return_only_if_complete => true,
              :disable_post_processing => true
            }

            # number of re-tries
            3.times do
              response = post(rest_url("assembly/get_action_results"),action_body)

              # server has found an error
              unless response.data(:results).nil?
                if response.data(:results)['error']
                  raise DTK::Client::DtkError, response.data(:results)['error']
                end
              end

              break if response.data(:is_complete)

              sleep(1)
            end

            raise DTK::Client::DtkError, "Error while logging there was no successful response after 3 tries." unless response.data(:is_complete)

            # due to complicated response we change its formating
            response = response.data(:results).first[1]

            unless response["error"].nil?
              raise DTK::Client::DtkError, response["error"]
            end

            # removing invalid chars from log
            output = response["output"].gsub(/`/,'\'')

            unless output.empty?
              file_ready = true
              tail_temp_file << output 
              tail_temp_file.flush
            end

            last_line = response["last_line"]
            sleep(LOG_SLEEP_TIME)
          end
        end

        t2 = Thread.new do
          # ramp up time
          begin
            if options.more?
              system("tail -f #{file_path} | more")
            else
              # needed ramp up time for t1 to start writting to file
              while not file_ready
                sleep(0.5)
              end
              system("less +F #{file_path}")
            end
          ensure
            # wheter application resolves normaly or is interrupted
            # t1 will be killed
            t1.exit()
          end
        end
        
        t1.join()
        t2.join()
      rescue Interrupt
        t2.exit()
      rescue DTK::Client::DtkError => e
        t2.exit()
        raise e
      end
    end

    desc "ASSEMBLY-NAME/ID grep LOG-PATH NODE-ID-PATTERN GREP-PATTERN [--first_match]","Grep log from multiple nodes"
    method_option :first_match, :type => :boolean, :default => false
    def grep(context_params)
      
    if context_params.is_there_identifier?(:node)
      mapping = [:assembly_id!,:option_1!,:node_id!,:option_2!]
    else
      mapping = [:assembly_id!,:option_1!,:option_2!,:option_3!]
    end

    assembly_id,log_path,node_pattern,grep_pattern = context_params.retrieve_arguments(mapping,method_argument_names)
       
    begin
      post_body = {
        :assembly_id         => assembly_id,
        :subtype             => 'instance',
        :log_path            => log_path,
        :node_pattern        => node_pattern,
        :grep_pattern        => grep_pattern,
        :stop_on_first_match => options.first_match?
      }

      response = post rest_url("assembly/initiate_grep"), post_body

      unless response.ok?
        raise DTK::Client::DtkError, "Error while getting log from server. Message: #{response['errors'][0]['message'].nil? ? 'There was no successful response.' : response['errors'].first['message']}"
      end

      action_results_id = response.data(:action_results_id)
      action_body = {
        :action_results_id => action_results_id,
        :return_only_if_complete => true,
        :disable_post_processing => true
      }

      # number of re-tries
      3.downto(1) do
        response = post(rest_url("assembly/get_action_results"),action_body)

        # server has found an error
        unless response.data(:results).nil?
          if response.data(:results)['error']
            raise DTK::Client::DtkError, response.data(:results)['error']
          end
        end

        break if response.data(:is_complete)

        sleep(1)
      end

      raise DTK::Client::DtkError, "Error while logging there was no successful response after 3 tries." unless response.data(:is_complete)
      
      console_width = ENV["COLUMNS"].to_i

      response.data(:results).each do |r|
        raise DTK::Client::DtkError, r[1]["error"] if r[1]["error"]

        if r[1]["output"].empty?
          puts "NODE-ID #{r[0].inspect.colorize(:green)} - Log does not contain data that matches you pattern #{grep_pattern}!" 
        else
          puts "\n"
          console_width.times do
            print "="
          end
          puts "NODE-ID: #{r[0].inspect.colorize(:green)}\n"
          puts "Log output:\n"
          puts r[1]["output"].gsub(/`/,'\'')
        end
      end
        
      rescue DTK::Client::DtkError => e
        raise e
      end
    end
    
    no_tasks do
      def assembly_start(assembly_id, node_pattern_filter)             
        post_body = {
          :assembly_id  => assembly_id,
          :node_pattern => node_pattern_filter
        }

        # we expect action result ID
        response = post rest_url("assembly/start"), post_body
        raise DTK::Client::DtkValidationError, response.data(:errors).first if response.data(:errors)
        # return response  if response.data(:errors)

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

        response = post rest_url("assembly/stop"), post_body
        raise DTK::Client::DtkValidationError, response.data(:errors).first if response.data(:errors)

        return response
      end


    end
  end
end

