module DTK::Client
  class Node < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:node)
    end

    def self.whoami()
      return :node, "node/list", nil
    end
    
    desc "list","List nodes"
    method_option "only-in-targets", :aliases => "-t", :type => :boolean
    method_option "only-in-libraries", :aliases => "-l", :type => :boolean
    method_option :list, :type => :boolean, :default => false
    def list()
      types = nil
      add_cols = []
      minus_cols = []
      add_filters = []
      if options["only-in-targets"]
        types = TargetTypes
        add_cols = [:operational_status,:datacenter_datacenter_id]
        add_filters << [:neq, ":datacenter_datacenter_id", nil] #to filter out library assemblies 
      elsif options["only-in-libraries"]
        types = LibraryTypes
        add_cols = [:library_library_id]
        minus_cols = [:type]
      else
        types = (TargetTypes + LibraryTypes) 
      end
      search_hash = SearchHash.new()
      search_hash.cols = (pretty_print_cols() + add_cols) - minus_cols
      search_hash.filter = 
        if add_filters.empty?
          [:oneof, ":type", types]
        else
          [:and,[:oneof, ":type", types]] + add_filters
        end
      response = post rest_url("node/list"), search_hash.post_body_hash()
      
      response.render_table(:node) unless options.list?
      return response
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

