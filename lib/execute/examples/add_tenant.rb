class DTK::Client::Execute

  def self.add_tenant(tenant_name,params={})
    component = "dtk_tenant[#{tenant_name}]"
    service = 'dtkhost5'
    node = 'server'
    tenant_password = params[:tenant_password] || 'foo'
    catalog_user_name = params[:catalog_user_name] || tenant_name

    ExecuteContext(:print_results => true) do
      result = call 'service/add_component',
        :service               => service,
        :node                  => node,
        :component             => component,
        :donot_update_workflow => true
      
      result = call 'service/set_attribute',
        :service        => service,
        :attribute_path => "#{node}/#{component}/tenant_password",
        :value          => tenant_password

      result = call 'service/set_attribute',
        :service        => service,
        :attribute_path => "#{node}/#{component}/catalog_user_name",
        :value          => catalog_user_name


    end
  end
end
