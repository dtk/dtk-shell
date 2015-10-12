module DTK::Client
  module NodeMixin
    def get_node_info(context_params)

      context_params.forward_options({ :json_return => true })
      # TODO: put this code on server side so dont need to do a query that 
      #       also info that comes back should indicate whether a node group and if so error message is that
      #       ssh cannot be called on node group
      response = info_aux(context_params)
      else
        response
      end
      if response.ok?
=begin
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
