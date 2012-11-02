module DTK::Client
  class NodeGroup < CommandBaseThor
    def self.pretty_print_cols()
      PPColumns.get(:node_group)
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

    desc "create NODE-GROUP-NAME", "Create node group"
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create node group in"
    def create(name)
      target_id = options["in-target"]
      save_hash = {
        :parent_model_name => "target",
        :display_name => name,
        :type => "node_group_instance"
      }
      #TODO: migrate to newer method stype than save
      save_hash[:parent_id] = target_id if target_id
      post rest_url("node_group/save"), save_hash
    end

    desc "delete NODE-GROUP-ID", "Delete node group"
    def delete(id)
      # Ask user if really want to delete node group, if not then return to dtk-shell without deleting
      return unless confirmation_prompt("Are you sure you want to delete node group '#{id}'?")

      delete_hash = {:id => id}
      post rest_url("node_group/delete"), delete_hash
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

    desc "members NODE-GROUP-ID", "Node group members"
    def members(node_group_id)
      get rest_url("node_group/members/#{node_group_id.to_s}")
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

   #######

    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:node_group, "node_group/list")
        
        unless (response.nil? || response.empty?)
          unless response['data'].nil?
            response['data'].each do |element|
              return true if (element['id'].to_s==value || element['display_name'].to_s==value)
            end
          end 
        end
        false
      end

      def self.get_identifiers(conn)
        ret = Array.new
        @conn    = conn if @conn.nil?
        response = get_cached_response(:node_group, "node_group/list")

        unless (response.nil? || response.empty?)
          unless response['data'].nil?
            identifiers = []
            response['data'].each do |element|
               identifiers << element['display_name']
            end
            return identifiers
          end
        end
        ret
      end
    end

  end
end

