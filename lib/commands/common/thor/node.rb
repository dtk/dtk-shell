module DTK::Client
  module NodeMixin
    def get_node_info_for_ssh_login(context_params)
=begin
      assembly_or_workspace_id = required_assembly_or_workspace_id(context_params)
      post_body = {
        :node_id => node_id,
        :subtype => 'instance',
      }

      ret = post rest_url("node/info"), post_body
=end
      context_params.forward_options(:json_return => true)
      response = info_aux(context_params)
      pp response 
raise Error.new
    end
  end
end
=begin
      context_params.forward_options({ :json_return => true })
      # TODO: put this code on server side so dont need to do a query that 
      #       also info that comes back should indicate whether a node group and if so error message is that
      #       ssh cannot be called on node group
      response = info_aux(context_params)
      else
        response
      end
      if response.ok?

    def node_info_aux
        node_info = {}
        response.data['nodes'].each do |node|
          properties = node['node_properties']
          node_info = properties if node_id == properties['node_id']
        end
        public_dns = node_info ? node_info['ec2_public_address'] : nil 
  end
end
=end
