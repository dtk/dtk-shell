
module DTK::Client
  class Attribute < CommandBaseThor

    def self.validation_list(context_params)

      assembly_id, node_id, component_id = context_params.retrieve_arguments([:assembly_id!, :node_id!, :component_id!])

      post_body = {
        :assembly_id  => assembly_id,
        :node_id      => node_id,
        :component_id => component_id,
        :subtype      => 'instance',
        :about        => 'attributes',
        :filter       => nil
      }

      response = get_cached_response(:assembly_node_component_attribute, "assembly/info_about", post_body)
      modified_response = response.clone_me()

      modified_response['data'].each { |e| e['display_name'] = e['display_name'].split('/').last }
        
      return modified_response
    end


  end
end