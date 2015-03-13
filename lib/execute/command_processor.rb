class DTK::Client::Execute
  class CommandProcessor
    dtk_require('command_processor/rest_call')

    def self.execute(command)
      if command.kind_of?(Command::RestCall)
        RestCall.execute(command)
      else
        raise ErrorUsage.new("Unexpected Command type: #{command.class}")
      end
    end
  end
end
