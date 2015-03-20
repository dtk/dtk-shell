class DTK::Client::Execute

  def self.add_tenant(tenant_name,params={})
    component_with_namespace = "dtk-meta-user:dtk_tenant[#{tenant_name}]"
    component_namespace, component = (component_with_namespace =~ /(^[^:]+):(.+$)/; [$1,$2])
    service = 'dtkhost5'
    node = 'server'
    tenant_password = params[:tenant_password] || 'foo'
    catalog_user_name = params[:catalog_user_name] || tenant_name

    ExecuteContext(:print_results => true) do
      result = call 'service/add_component',
        :service               => service,
        :node                  => node,
        :component             => component,
        :namespace             => component_namespace,
        :donot_update_workflow => true
      
      result = call 'service/set_attribute',
        :service        => service,
        :attribute_path => "#{node}/#{component}/tenant_password",
        :value          => tenant_password

      result = call 'service/set_attribute',
        :service        => service,
        :attribute_path => "#{node}/#{component}/catalog_user_name",
        :value          => catalog_user_name

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
