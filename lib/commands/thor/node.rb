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
      [:component]
    end

    def self.valid_child?(name_of_sub_context)
      return Node.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!])

      if assembly_id
        # if assebmly_id is present we're loading nodes filtered by assembly_id
        post_body = {
          :assembly_id => assembly_id,
          :subtype     => 'instance',
          :about       => 'nodes',
          :filter      => nil
        }

        response = get_cached_response(:assembly_node, "assembly/info_about", post_body)
      else
        # otherwise, load all nodes
        response = get_cached_response(:node, "node/list", nil)
      end

      return response
    end
    
    desc "NODE-NAME/ID info","Info about node"
    def info(context_params)

      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      post_body = {
        :node_id => node_id,
        :subtype => 'instance',
      }
       post rest_url("node/info"), post_body
    end

    desc "[NODE-NAME/ID] list [components|attributes]","List components that are on the node instance."
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
          when "components":
            data_type = :component
          when "attributes":
            data_type = :attribute
          else
            raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
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

    desc "NODE-NAME/ID add-component COMPONENT-TEMPLATE-NAME/ID [-v VERSION]", "Add component template to node"
    version_method_option
    def add_component(context_params)
      node_id,component_template_id = context_params.retrieve_arguments([:node_id!, :option_1!],method_argument_names)
      post_body = {
        :node_id => node_id,
        :component_template_name => component_template_name
      }
      post_body.merge!(:version => options[:version]) if options[:version]

      post rest_url("node/add_component"), post_body
    end

    desc "NODE-NAME/ID delete-component COMPONENT-ID", "Delete component from node"
    def delete_component(context_params)
      node_id,component_id = context_params.retrieve_arguments([:node_id!, :option_1!],method_argument_names)
      post_body = {
        :node_id => node_id,
        :component_id => component_id
      }
      post rest_url("node/delete_component"), post_body
    end

    desc "NODE-NAME/ID converge [-m COMMIT-MSG]", "Converges assembly instance"
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
      post_body.merge!(:commit_msg => options.commit_msg) if options.commit_msg

      response = post rest_url("node/create_task"), post_body
      return response unless response.ok?

      # execute task
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "NODE-NAME/ID task-status [--wait]", "Task status of running or last assembly task"
    method_option :wait, :type => :boolean, :default => false
    def task_status(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      task_status_aux(node_id,:node,options.wait?)
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
      assembly_id,node_id = get_assembly_and_node_id(context_params)
      assembly_start(assembly_id, node_id)
    end

    desc "NODE-NAME/ID stop", "Stop node instance."
    def stop(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      # Retrieving assembly_id to stop a node.. TODO create server side method that takes only node id
      assembly_id, node_id = get_assembly_and_node_id(context_params)
      assembly_stop(assembly_id, node_id)
    end

    no_tasks do
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

