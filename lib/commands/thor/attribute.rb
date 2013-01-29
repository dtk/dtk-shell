
module DTK::Client
  class Attribute < CommandBaseThor

    def self.validation_list(context_params)

      assembly_id, node_name, component_name = context_params.retrieve_arguments([:assembly_id, :node_name, :component_name])

      post_body = {
        :assembly_id => assembly_id,
        :subtype     => 'instance',
        :about       => 'attributes',
        :filter      => nil
      }

      # TODO: Use cahced response here issue with duplication when we changing response
      #response = get_cached_response(:attribute, "assembly/info_about", post_body)
      response = post rest_url("assembly/info_about"), post_body

     if assembly_id
        regexp = Regexp.new("node\[#{node_name}\].?cmp\[#{component_name}\].+")

        response['data'] = response['data'].select {|element| (element['display_name'].include?(component_name) && element['display_name'].include?(node_name)) }
        response['data'].each do |e|
          e['display_name'] = e['display_name'].split('/').last
        end
      end
         
      return response
    end


  end
end