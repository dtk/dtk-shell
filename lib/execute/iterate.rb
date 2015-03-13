class DTK::Client::Execute
  # Iterate provides functionality to iterate over script commands
  class Iterate
    dtk_require('iterate/result_store')
    dtk_require('iterate/rest_call')

    def initialize()
      @result_store = ResultStore.new()
    end
    def self.iterate_over_script(commands)
      new().iterate_over_script(commands)
    end

    def iterate_over_script(commands)
      Array(commands).each do |command|
        result = 
          if command.kind_of?(Command::RestCall)
            RestCall.execute(command)
          else
            raise ErrorUsage.new("Unexpected Command type: #{command.class}")
          end
        pp(:command => command, :result => result)
        @result_store.store_result(result,command.result_var)
      end
    end

  end
end
