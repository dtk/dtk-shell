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

    LibraryTypes = ["image"]
    TargetTypes = ["staged","instance"]

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

