module DTK::Client
  class Execute
    # The order matters
    dtk_require('execute/error_usage')
    dtk_require('execute/command')
    dtk_require('execute/iterate')

    def self.test()
      command = Command::RestCall::Post.new(:path => 'service_module/list')

      Iterate.iterate_over_script(command)

    end
  end
end
