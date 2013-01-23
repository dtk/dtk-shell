
module DTK::Client
  class Attribute < CommandBaseThor

    def self.validation_list(hashed_args)

      assembly_id, node_id, component_id = CommandBaseThor.retrieve_arguments([:assembly_id, :node_id, :component_id],hashed_args)

      post_body = {
        :assembly_id => assembly_id,
        :subtype     => 'instance',
        :about       => 'attributes',
        :filter      => nil
      }

      response = get_cached_response(:attribute, "assembly/info_about", post_body)

     if assembly_id
        regexp = Regexp.new("node\[#{node_id}\].?cmp\[#{component_id}\].+")

        response['data'] = response['data'].select {|element| (element['display_name'].include?(component_id) && element['display_name'].include?(node_id)) }
        response['data'].each do |e|
          e['display_name'] = e['display_name'].split('/').last
        end
      end
         
      return response
    end

  end
end