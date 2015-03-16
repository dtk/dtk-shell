module DTK::Client
  class Execute
    # The order matters
    dtk_require('execute/error_usage')
    dtk_require('execute/command')
    dtk_require('execute/command_processor')
    dtk_require('execute/execute_context')
#    dtk_require('execute/iterate')

    extend ExecuteContext::ClassMixin
    def self.test(component,params={})
      ExecuteContext(:print_results => true) do
        result = call 'service/add_component',
          :service               => 'dtkhost5',
          :node                  => 'server', 
          :component             => component,
          :donot_update_workflow => true

        result = call 'service/set_attribute',
          :service        => 'dtkhost5',
          :attribute_path => "server/#{component}/tenant_password",
          :value          => params[:tenant_password] || 'foo'

      end
    end

  end
end
