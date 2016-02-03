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
=begin
      ExecuteContext(:print_results => true) do
        result = call_v1 'services/create',
          service_module_name: service_module_name,
          assembly_name: assembly_name
      end
=end
      ExecuteContext(:print_results => true) do
        result = get_call_v1 'services/_info',id: 2147783388
      end
pp result
    end
  end
end
