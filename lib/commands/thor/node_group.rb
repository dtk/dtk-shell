dtk_require_common_commands('thor/task_status')
module DTK::Client
  class NodeGroup < CommandBaseThor
    no_tasks do
      include TaskStatusMixin
    end

    def self.pretty_print_cols()
      PPColumns.get(:node_group)
    end


    def self.whoami()
      return :node_group, "node_group/list", nil
    end

    desc "list","List Node groups"
    def list()
      search_hash = SearchHash.new()
      search_hash.cols = pretty_print_cols()
      search_hash.filter = [:oneof, ":type", ["node_group_instance"]]
      post rest_url("node_group/list"), search_hash.post_body_hash()
    end

    #TODO: may write common inherited version of set_required_params accross commands that need it
    desc "NODE-GROUP-NAME/ID set-required-params", "Interactive dialog to set required params that are not currently set"
    def set_required_params(node_group_id)
      post_body = {
        :node_group_id => node_group_id,
        :subtype     => 'instance',
        :filter      => 'required_unset_attributes'
      }
      response = post rest_url("node_group/get_attributes"), post_body
      return response unless response.ok?
      missing_params = response.data
      if missing_params.empty?
        response.set_data('Message' => "No parameters to set.")
        response
      else
        param_bindings = DTK::Shell::InteractiveWizard.new.resolve_missing_params(missing_params)
        post_body = {
          :node_group_id => node_group_id,
          :av_pairs_hash => param_bindings.inject(Hash.new){|h,r|h.merge(r[:id] => r[:value])}
        }
        response = post rest_url("node_group/set_attributes"), post_body
        return response unless response.ok?
        response.data
      end
    end

    desc "create NODE-GROUP-NAME [-t TARGET-ID] [--spans-target]", "Create node group"
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create node group in"
    method_option "spans-target", :type => :boolean, :default => false
    def create(name)
      target_id = options["in-target"]
      post_body = {
        :display_name => name
      }
      post_body[:target_id] = target_id if target_id
      post_body[:spans_target] = true if options["spans-target"]
      post rest_url("node_group/create"), post_body
    end

    desc "delete NODE-GROUP-ID", "Delete node group"
    def delete(id)
      # Ask user if really want to delete node group, if not then return to dtk-shell without deleting
      return unless confirmation_prompt("Are you sure you want to delete node group '#{id}'?")

      post_body = {:node_group_id => id}
      post rest_url("node_group/delete"), post_body
    end

    desc "NODE-GROUP-NAME/ID show components|attributes","List components or attributes that are on the node group."
    def show(*rotated_args)
      #TODO: working around bug where arguments are rotated; below is just temp workaround to rotate back
      node_group_id,about = rotate_args(rotated_args)

      post_body = {
        :node_group_id => node_group_id,
        :about         => about
      }

      case about
        when "components":
          data_type = :component
        when "attributes":
          data_type = :attribute
        else
          raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
      end

      response = post rest_url("node_group/info_about"), post_body
      response.render_table(data_type)
    end

    desc "NODE-GROUP-NAME/ID members", "List node group members"
    def members(node_group_id)
      post_body = {
        :node_group_id => node_group_id
      }
      response = post rest_url("node_group/get_members"), post_body
      response.render_table(:node)
    end

    desc "NODE-GROUP-NAME/ID add-component COMPONENT-TEMPLATE-ID", "Add component template to node group"
    def add_component(arg1,arg2)
      node_group_id,component_template_id = [arg2,arg1]
      post_body = {
        :node_group_id => node_group_id,
        :component_template_id => component_template_id
      }
      post rest_url("node_group/add_component"), post_body
    end

    desc "NODE-GROUP-NAME/ID delete-component COMPONENT-ID", "Delete component from  node group"
    def delete_component(arg1,arg2)
      node_group_id,component_id = [arg2,arg1]
      post_body = {
        :node_group_id => node_group_id,
        :component_id => component_id
      }
      post rest_url("node_group/delete_component"), post_body
    end

    desc "NODE-GROUP-NAME/ID converge [-m COMMIT-MSG]", "Converges assembly instance"
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def converge(node_group_id)
      # create task
      post_body = {
        :node_group_id => node_group_id
      }
      post_body.merge!(:commit_msg => options["commit_msg"]) if options["commit_msg"]

      response = post rest_url("node_group/create_task"), post_body
      return response unless response.ok?

      # execute task
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "NODE-GROUP-NAME/ID task-status [--wait]", "Task status of running or last assembly task"
    method_option :wait, :type => :boolean, :default => false
    def task_status(node_group_id)
      task_status_aux(node_group_id,:node_group,options)
    end

    #TODO: may deprecate
=begin
    desc "set-profile NODE-GROUP-ID TEMPLATE-NODE-ID", "Set node group's default node template"
    def set_profile(node_group_id,template_node_id)
      post_body_hash = {:node_group_id => node_group_id, :template_node_id => template_node_id}
      post rest_url("node_group/set_default_template_node"),post_body_hash
    end

    desc "add-template-node NODE-GROUP-ID", "Copy template node from library and add to node group"
    def add_template_node(node_group_id)
      post_body_hash = {:node_group_id => node_group_id}
      post rest_url("node_group/clone_and_add_template_node"),post_body_hash
    end
=end

  end
end

