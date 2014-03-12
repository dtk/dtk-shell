dtk_require_common_commands('thor/task_status')
dtk_require_common_commands('thor/set_required_params')
module DTK::Client
  class Node < CommandBaseThor

    no_tasks do
      include TaskStatusMixin
      include SetRequiredParamsMixin
    end

    def self.pretty_print_cols()
      PPColumns.get(:node)
    end

    def self.valid_children()
      [:component, :utils]
    end

    def self.multi_context_children()
      [:utils]
    end

    def self.all_children()
      [:component, :attribute]
      # [:node]
    end

    # using extended_context when we want to use autocomplete from other context
    # e.g. we are in assembly/apache context and want to create-component we will use extended context to add 
    # component-templates to autocomplete
    def self.extended_context()
      {
        :context => {
          :add_component => "component_template"
        }
      }
    end

    def self.valid_child?(name_of_sub_context)
      return Node.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      assembly_id, workspace_id = context_params.retrieve_arguments([:service_id, :workspace_id])
      
      if (assembly_id || workspace_id)
        # if assebmly_id is present we're loading nodes filtered by assembly_id
        post_body = {
          :assembly_id => assembly_id||workspace_id,
          :subtype     => 'instance',
          :about       => 'nodes',
          :filter      => nil
        }

        response = get_cached_response(:service_node, "assembly/info_about", post_body)
      else
        # otherwise, load all nodes
        response = get_cached_response(:node, "node/list", nil)
      end

      return response
    end

    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :command_only => {
          :utils => [
            ['get-netstats',"get-netstats","# Get netstats."],
            ['get-ps',"get-ps [--filter PATTERN]","# Get ps."]
          ]
        }
      })
    end
    
    desc "NODE-NAME/ID info","Info about node"
    def info(context_params)
      raise
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      post_body = {
        :node_id => node_id,
        :subtype => 'instance',
      }

       post rest_url("node/info"), post_body
    end

    desc "NODE-NAME/ID ssh [--keypair] [--remote-user]","SSH into node, optional parameters are path to keypair and remote user."
    method_option "--keypair",:type => :string, :desc => "Keypair used for connection, if not provided default is used", :banner => "KEYPAIR"
    method_option "--remote-user",:type => :string, :desc => "Remote user used for connection", :banner => "REMOTE USER"
    def ssh(context_params)
      if OsUtil.is_windows?
        puts "[NOTICE] SSH functionality is currenly not supported on Windows."
        return
      end

      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)


      keypair_location = options.keypair || OsUtil.dtk_keypair_location()


      remote_user = options.send('remote-user') || 'ubuntu'

      unless File.exists?(keypair_location||'')
        error_message = keypair_location ? "Not able to find keypair, '#{keypair_location}'" : "Default keypair not set, please provide one in 'ssh' command"
        raise ::DTK::Client::DtkError, error_message
      end

      response = post rest_url("node/info"), { :node_id => node_id, :subtype => 'instance' }

      if response.ok?
        public_dns = response.data['external_ref']['ec2_public_address']

        raise ::DTK::Client::DtkError, "Not able to resolve instance address, has instance been stopped?" unless public_dns

        connection_string = "#{remote_user}@#{public_dns}"
        ssh_command = "ssh  -o \"StrictHostKeyChecking no\" -o \"UserKnownHostsFile /dev/null\" -i #{keypair_location} #{connection_string}"

        OsUtil.print("You are entering SSH terminal (#{connection_string}) ...", :yellow)
        Kernel.system(ssh_command)
        OsUtil.print("You are leaving SSH terminal, and returning to DTK Shell ...", :yellow)
      else
        return response
      end
    end

    desc "NODE-NAME/ID list-components","List components that are on the node instance."
    method_option :list, :type => :boolean, :default => false
    def list_components(context_params)
      context_params.method_arguments = ["components"]
      list(context_params)
    end

    desc "NODE-NAME/ID list-attributes","List attributes that are on the node instance."
    method_option :list, :type => :boolean, :default => false
    def list_attributes(context_params)
      context_params.method_arguments = ["attributes"]
      list(context_params)
    end

    desc "list","List components that are on the node instance."
    method_option :list, :type => :boolean, :default => false
    def list(context_params)
      node_id, about = context_params.retrieve_arguments([:node_id,:option_1],method_argument_names)
      
      if node_id.nil?
        response = post rest_url("node/list")

        response.render_table(:node) unless options.list?
        return response
      else

        post_body = {
          :node_id => node_id,
          :subtype => 'instance',
          :about   => about
        }

        case about
          when "components"
            data_type = :component
          when "attributes"
            data_type = :attribute
          else
            raise_validation_error_method_usage('list')
        end

        response = post rest_url("node/info_about"), post_body
        return response.render_table(data_type)
      end
    end

    desc "NODE-NAME/ID set ATTRIBUTE-ID VALUE", "Set node group attribute value"
    def set(context_params)
      node_id, attr_id, value = context_params.retrieve_arguments([:node_id!, :option_1!, :option_2!],method_argument_names)
      post_body = {
        :node_id => node_id,
        :pattern => attr_id,
        :value => value
      }
      post rest_url("node/set_attributes"), post_body
    end

    desc "NODE-NAME/ID set-required-params", "Interactive dialog to set required params that are not currently set"
    def set_required_params(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      set_required_params_aux(node_id,:node)
    end

    # desc "NODE-NAME/ID create-component COMPONENT-TEMPLATE-NAME/ID [-v VERSION]", "Add component template to node"
    # version_method_option
    desc "NODE-NAME/ID add-component COMPONENT-TEMPLATE-NAME/ID", "Add component template to node"
    def add_component(context_params)
      node_id,component_template_id = context_params.retrieve_arguments([:node_id!, :option_1!],method_argument_names)
      post_body = {
        :node_id => node_id,
        :component_template_name => component_template_id
      }
      post_body.merge!(:version => options[:version]) if options[:version]

      response = post rest_url("node/add_component"), post_body
      return response unless response.ok?

      @@invalidate_map << :node
      return response
    end

    desc "NODE-NAME/ID delete-component COMPONENT-ID [-y]", "Delete component from node"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_component(context_params)
      node_id,component_id = context_params.retrieve_arguments([:node_id!, :option_1!],method_argument_names)

      unless options.force?
        return unless Console.confirmation_prompt("Are you sure you want to delete component '#{component_id}'"+'?')
      end

      post_body = {
        :node_id => node_id,
        :component_id => component_id
      }
      post rest_url("node/delete_component"), post_body
    end

    desc "NODE-NAME/ID converge [-m COMMIT-MSG]", "Converges service instance"
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def converge(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      # create task
      post_body = {
        :node_id => node_id
      }

      response = post rest_url("node/find_violations"), post_body
      return response unless response.ok?
      if response.data and response.data.size > 0
        #TODO: may not directly print here; isntead use a lower level fn
        error_message = "The following violations were found; they must be corrected before the node can be converged"
        DTK::Client::OsUtil.print(error_message, :red)
        return response.render_table(:violation)
      end

      post_body.merge!(:commit_msg => options.commit_msg) if options.commit_msg

      response = post rest_url("node/create_task"), post_body
      return response unless response.ok?

      # execute task
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "NODE-NAME/ID task-status [--wait]", "Task status of running or last service task"
    method_option :wait, :type => :boolean, :default => false
    def task_status(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      task_status_aux(node_id,:node,options.wait?)
    end

    desc "NODE-NAME/ID list-task-info", "Task status details of running or last service task"
    def list_task_info(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      list_task_info_aux("node", node_id)
    end

    desc "NODE-NAME/ID cancel-task TASK_ID", "Cancels task."
    def cancel_task(context_params)
      task_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      cancel_task_aux(task_id)
    end

    # desc "list-smoketests ASSEMBLY-ID","List smoketests on asssembly"
    desc "destroy NODE-ID", "Delete and destroy (terminate) node"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def destroy(context_params)
      node_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      post_body = {
        :node_id => node_id
      }
      unless options.force?
        # Ask user if really want to delete and destroy, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to destroy and delete node '#{node_id}'?")
      end

      response = post rest_url("node/destroy_and_delete"), post_body
      @@invalidate_map << :node

      return response
    end

    desc "NODE-NAME/ID op-status", "Get node operational status"
    def op_status(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      post rest_url("node/get_op_status"), :node_id => node_id
    end

    desc "NODE-NAME/ID start", "Start node instance."
    def start(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      #TODO: Rich: took this out; think it is a bug
      #assembly_id,node_id = get_assembly_and_node_id(context_params)

      node_start(node_id)
    end

    desc "NODE-NAME/ID stop", "Stop node instance."
    def stop(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      # Retrieving assembly_id to stop a node.. TODO create server side method that takes only node id
      #TODO: Rich: took this out; think it is a bug
      #assembly_id, node_id = get_assembly_and_node_id(context_params)
      
      node_stop(node_id)
    end

    desc "HIDE_FROM_BASE get-netstats", "Get netstats"
    def get_netstats(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)

      post_body = {
        :node_id => node_id
      }  

      response = post(rest_url("node/initiate_get_netstats"), post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => false
        }
        response = post(rest_url("node/get_action_results"),post_body)
        count += 1
        if count > GETNETSTATSTRIES or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == GETNETSTATSTRIES
            ret_only_if_complete = false
          end
          sleep GETNETSTATSSLEEP
        end
      end

      #TODO: needed better way to render what is one of teh feileds which is any array (:results in this case)
      response.set_data(*response.data(:results))
      response.render_table(:netstat_data)
    end
    GETNETSTATSTRIES = 6
    GETNETSTATSSLEEP = 0.5

    desc "HIDE_FROM_BASE get-ps [FILTER]", "Get ps"
    def get_ps(context_params)
      node_id, filter_pattern = context_params.retrieve_arguments([:node_id!, :option_1],method_argument_names)

      post_body = {
        :node_id => node_id
      }  

      response = post(rest_url("node/initiate_get_ps"), post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => true
        }
        response = post(rest_url("node/get_action_results"),post_body)
        count += 1
        if count > GETPSTRIES or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == GETPSTRIES
            ret_only_if_complete = false
          end
          sleep GETPSSLEEP
        end
      end

      response_processed = response.data['results'].values.flatten
      response_processed.reject! {|r| !r.to_s.include?(filter_pattern)} unless filter_pattern.nil?

      #TODO: needed better way to render what is one of teh feileds which is any array (:results in this case)
      response.set_data(*response_processed)
      response.render_table(:ps_data)
    end
    GETPSTRIES = 6
    GETPSSLEEP = 0.5

    no_tasks do
      def node_start(node_id)             
        post_body = {
          :node_id  => node_id
        }

        # we expect action result ID
        response = post rest_url("node/start"), post_body
        return response  if response.data(:errors)

        action_result_id = response.data(:action_results_id)

        # bigger number here due to possibilty of multiple nodes
        # taking too much time to be ready
        18.times do
          action_body = {
            :action_results_id  => action_result_id,
            :using_simple_queue => true
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

      def node_stop(node_id)
        post_body = {
          :node_id => node_id
        }

        post rest_url("node/stop"), post_body
      end
      # get numeric ID, from possible name id
      def get_assembly_and_node_id(context_params)
        response = info(context_params)
        unless response.ok?
          raise DTK::Client::DtkError, "Unable to retrive node information, please try again."
        end      

        return response.data(:assembly_id), response.data(:id)
      end
    end
  end
end

