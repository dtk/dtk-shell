class DTK::Client::Execute::Script
  class IgniteCluster < self
    def self.ret_params_from_argv()
      banner = "Usage: dtk-execute ignite-cluster"
      unless ARGV.size == 1
        show_help_and_exit(banner)
      end
      {}
    end

    def self.execute_with_params(params)
      service_module_name = 'bigtop:ignite'
      assembly_name = 'cluster'
      result = nil
      ExecuteContext(:print_results => true) do
        result = call_v1 'services/create',
          service_module_name: service_module_name,
          assembly_name: assembly_name
      end

      service_id = result.first['id']

      ExecuteContext(:print_results => true) do
        get_call_v1 'services/_info',id: service_id
      end

      ExecuteContext(:print_results => true) do
        delete_call_v1 'services',id: service_id
      end
    end
  end
end
