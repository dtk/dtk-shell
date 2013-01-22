
module DTK::Client
  class Component < CommandBaseThor

    def self.whoami()
      return :component, "component/list", nil
    end

    def self.validation_list(hashed_args)

      assembly_id, node_id = CommandBaseThor.retrieve_arguments([:assembly_id, :node_id],hashed_args)

      post_body = {
        :assembly_id => assembly_id,
        :subtype     => 'instance',
        :about       => 'components',
        :filter      => nil
      }

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

  end
end