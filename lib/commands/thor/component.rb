
module DTK::Client
  class Component < CommandBaseThor

    def self.valid_children()
      [:attribute]
    end

    def self.valid_child?(name_of_sub_context)
      return Component.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)

      assembly_or_worspace_id, node_id, node_name = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!], :node_id!, :node_name!])

      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :node_id     => node_id,
        :subtype     => 'instance',
        :about       => 'components',
        :filter      => nil
      }

      response = get_cached_response(:assembly_node_component, "assembly/info_about", post_body)
      
      modified_response = response.clone_me()
      modified_response['data'].each { |e| e['display_name'] = e['display_name'].split('/').last }

      return modified_response
    end

    desc "ASSEMBLY-NAME/ID set ATTRIBUTE-PATTERN VALUE", "Set target component attributes"
    def set(context_params)
      assembly_id, node_id, component_id, pattern, value = context_params.retrieve_arguments([:assembly_id, :node_id, :component_id, :option_1,:option_2],method_argument_names)
      post_body = {
        :assembly_id => assembly_id,
        :pattern => pattern,
        :value => value
      }
      #TODO: have this return format like assembly show attributes with subset of rows that gt changed
      post rest_url("assembly/set_attributes"), post_body
    end

  end
end