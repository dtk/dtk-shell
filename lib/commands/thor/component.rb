
module DTK::Client
  class Component < CommandBaseThor

    def self.valid_children()
      [:attribute]
    end

    def self.valid_child?(name_of_sub_context)
      return Component.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(hashed_args)

      assembly_id, node_id = CommandBaseThor.retrieve_arguments([:assembly_id, :node_id],hashed_args)

      post_body = {
        :assembly_id => assembly_id,
        :subtype     => 'instance',
        :about       => 'components',
        :filter      => nil
      }

      # TODO: Use cahced response here issue with duplication when we changing response
      #response = get_cached_response(:component, "assembly/info_about", post_body)
      response = post rest_url("assembly/info_about"), post_body

      if assembly_id
        regexp = Regexp.new("^#{node_id}\/(.+)")
        response['data'] = response['data'].select {|element| element['display_name'].match(regexp) }
        response['data'].each do |e|
          match_data = e['display_name'].match(regexp)
          e['display_name'] = match_data[1] if match_data
        end
      end

      return response
    end

    desc "ASSEMBLY-NAME/ID set ATTRIBUTE-PATTERN VALUE", "Set target component attributes"
    def set(hashed_args)
      assembly_id, node_id, component_id, pattern, value = CommandBaseThor.retrieve_arguments([:assembly_id, :node_id, :component_id, :option_1,:option_2],hashed_args)
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