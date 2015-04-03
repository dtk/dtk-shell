class DTK::Client::Execute::Script
  class AddTenant < self
    def self.ret_params_from_argv()
      banner = "Usage: dtk-execute add-tenant TENANT-NAME CATALOG-USERNAME -p PASSWORD [-s SERVICE-INSTANCE]"
      tenant_name = catalog_username = tenant_number = nil
      if ARGV.size > 2
        tenant_name = ARGV[1]
        if tenant_name =~ /^dtk([0-9]+)$/
          tenant_number = $1
        else
          raise ErrorUsage.new("TENANT-NAME must be of form 'dtkNUMs', like dtk601")
        end
        catalog_username = ARGV[2]
      else
        show_help_and_exit(banner)
      end

      params = Hash.new 
      process_params_from_options(banner) do |opts|
        opts.on( '-p', '--password PASSWORD', "Password for tenant and catalog" ) do |pw|
          params[:password] = pw
        end
        opts.on( '-s', '--service SERVICE-INSTANCE', "Name of Service instance" ) do |s|
          params[:service_instance] = s
        end
      end

      # TODO: use opt parser to enforce that :password option is manditory
      unless password = params[:password]
        raise ErrorUsage.new("Password is mandatory; use -p commnd line option")
      end
      service_instance = params[:service_instance] || "dtkhost#{tenant_number[0]}"
      to_add = {
        :tenant_name      => tenant_name,
        :catalog_username => catalog_username,
        :service_instance => service_instance
      }
      params.merge(to_add)
    end

    def self.execute_with_params(params)
      tenant_name =  params[:tenant_name]
      catalog_username = params[:catalog_username]
      service = params[:service_instance]
      password = params[:password]
      node = params[:node_name] || 'server'
      
      component_with_namespace = "dtk-meta-user:dtk_tenant[#{tenant_name}]"
      component_namespace, component = (component_with_namespace =~ /(^[^:]+):(.+$)/; [$1,$2])

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
end
