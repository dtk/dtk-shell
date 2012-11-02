module DTK::Client
  class Node < CommandBaseThor

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

    desc "add-to-group NODE-ID NODE-GROUP-ID", "Add node to group"
    def add_to_group(node_id,node_group_id)
      post_body = {
        :node_id => node_id,
        :node_group_id => node_group_id
      }
      post rest_url("node/add_to_group"), post_body
    end

    #TODO: temp for testing; should be on target
    desc "destroy-all", "Delete and destory all target nodes"
    def destroy_all()
      # Ask user if really want to delete and destroy all target node, if not then return to dtk-shell without deleting
      return unless confirmation_prompt("Are you sure you want to delete and destroy all target nodes?")

      post rest_url("project/destroy_and_delete_nodes")
    end
    
  end
end

