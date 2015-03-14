module DTK::Client
  class Execute
    # The order matters
    dtk_require('execute/error_usage')
    dtk_require('execute/command')
    dtk_require('execute/command_processor')
    dtk_require('execute/execute_context')
#    dtk_require('execute/iterate')

    extend ExecuteContext::ClassMixin
    def self.test()
      ExecuteContext(:print_results => true) do
        result = call 'service/add_component',
          :assembly_id           => 'dtkhost5',
          :node_id               => 'server', 
          :component_template_id => 'dtk_tenant[dtk529]'
      end
    end

    def self.test2()
      ExecuteContext(:print_results => true) do

        # add component; we want to modify so there is a flag that allows this to be idemponent and another one to indicate not to add to base workflow 
        result = post_rest_call 'assembly/add_component',
          :assembly_id           => 'dtkhost5',
          :subtype               => 'instance',
          :node_id               => 'server', 
          :component_template_id => 'dtk_tenant[dtk529]'
      end
    end
  end
end
