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

    def self.whoami()
      return :node, "node/list", nil
    end
    
    desc "list","List node insatnces"
    def list()
      response = post rest_url("node/list")
      response.render_table(:node)
    end

    desc "NODE-NAME/ID show components","List components that are on the node instance."
    def show(*rotated_args)
      #TODO: working around bug where arguments are rotated; below is just temp workaround to rotate back
      node_id,about = rotate_args(rotated_args)

      post_body = {
        :node_id => node_id,
        :subtype => 'instance',
        :about   => about
      }

      case about
        when "components":
          data_type = :component
        #TODO: treat
        #when "attributes":
        #  data_type = :attribute
        else
          raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
      end

      response = post rest_url("node/info_about"), post_body
      response.render_table(data_type)
    end

    desc "NODE-NAME/ID set-required-params", "Interactive dialog to set required params that are not currently set"
    def set_required_params(node_id)
      set_required_params_aux(node_id,:node)
    end

    desc "NODE-NAME/ID add-component COMPONENT-TEMPLATE-ID", "Add component template to node"
    def add_component(arg1,arg2)
      node_id,component_template_id = [arg2,arg1]
      post_body = {
        :node_id => node_id,
        :component_template_id => component_template_id
      }
      post rest_url("node/add_component"), post_body
    end

    desc "NODE-NAME/ID delete-component COMPONENT-ID", "Delete component from node"
    def delete_component(arg1,arg2)
      node_id,component_id = [arg2,arg1]
      post_body = {
        :node_id => node_id,
        :component_id => component_id
      }
      post rest_url("node/delete_component"), post_body
    end

    desc "destroy NODE-NAME/ID", "Delete and destroy (terminate) node"
    def destroy(node_id)
      post_body = {
        :node_id => node_id
      }
      # Ask user if really want to delete and destroy, if not then return to dtk-shell without deleting
      return unless confirmation_prompt("Are you sure you want to destroy and delete node (#{node_id})?")

      post rest_url("node/destroy_and_delete"), post_body
    end

=begin
TODO: not used yet
    desc "add-to-group NODE-ID NODE-GROUP-ID", "Add node to group"
    def add_to_group(node_id,node_group_id)
      post_body = {
        :node_id => node_id,
        :node_group_id => node_group_id
      }
      post rest_url("node/add_to_group"), post_body
    end
=end
  end
end

