class DTK::Client::Execute

  def self.add_tenant(tenant_name,catalog_username,params={})
    component_with_namespace = "dtk-meta-user:dtk_tenant[#{tenant_name}]"
    component_namespace, component = (component_with_namespace =~ /(^[^:]+):(.+$)/; [$1,$2])
    service = params[:service_instance] || 'dtkhost5'
    node = params[:node_name] || 'server'
    unless password = params[:password]
      raise ErrorUsage.new("Password is manditory; use -p commadn line option")
    end

    av_pairs = {
      :catalog_username => catalog_username,
      :tenant_password  => password,
      :catalog_password => password
    }

    ExecuteContext(:print_results => true) do
      result = call 'service/add_component',
        :service               => service,
        :node                  => node,
        :component             => component,
        :namespace             => component_namespace,
        :donot_update_workflow => true

      av_pairs.each_pair do |a,v|
        result = call 'service/set_attribute',
          :service        => service,
          :attribute_path => "#{node}/#{component}/#{a}",
          :value          => v
      end
  
      ['dtk_postgresql::databases'].each do |shared_service_component|
        result = call 'service/link_components',
          :service          => service,
          :input_component  => "#{node}/#{component}",
          :output_component => "#{node}/#{shared_service_component}"
      end

      result = call 'service/execute_workflow',
        :service         => service,
        :workflow_name   => 'add_tenant',
        :workflow_params => {'name' => tenant_name}

    end
  end
end
