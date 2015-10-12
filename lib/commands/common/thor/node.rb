module DTK::Client
  module NodeMixin
    def get_node_info_for_ssh_login(node_id, context_params)
      context_params.forward_options(:json_return => true)
      response = info_aux(context_params)
      return response unless response.ok?
      # Should only have info about the specfic node_id
      
      unless node_info = response.data(:nodes).find{ |node| node_id == (node['node_properties'] || {})['node_id'] }
        raise DtkError, "Cannot find info about node with id '#{node_id}'"
      end

      data = {}
      node_properties = node_info['node_properties'] || {}
      if public_dns = node_properties['ec2_public_address']
        data.merge!('public_dns' => public_dns)
      end
      if default_login_user = NodeMixin.default_login_user?(node_properties)
        data.merge!('default_login_user' => default_login_user)
      end

      Response::Ok.new(data)
    end

    def self.default_login_user?(node_properties)
    if os_type = node_properties['os_type']
        DefaultLoginByOSType[os_type]
      end
    end

    DefaultLoginByOSType = {
      'ubuntu'       => 'ubuntu',
      'amazon-linux' => 'ec2-user'
    }
  end
end
