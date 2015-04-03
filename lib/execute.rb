module DTK::Client
  class Execute
    # The order matters
    dtk_require('execute/error_usage')
    dtk_require('execute/command')
    dtk_require('execute/command_processor')
    dtk_require('execute/execute_context')
    dtk_require('execute/script')

    extend ExecuteContext::ClassMixin
  end
end

