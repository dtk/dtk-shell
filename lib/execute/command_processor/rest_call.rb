class DTK::Client::Execute; class CommandProcessor
  class RestCall< self
    extend ::DTK::Client::CommandBase # TODO: have a Base that is not just for commands (CommandBase)
    
    def self.execute(rest_command)
      response = raw_execute(rest_command)
      if response.ok?
        response.data
      else
        raise Error.new(response,rest_command)
      end
    end

    private
    def self.raw_execute(rest_command)
      if rest_command.kind_of?(Command::RestCall::Post)
        post(rest_url(rest_command.path),rest_command.body)
      elsif rest_command.kind_of?(Command::RestCall::Get)
        get(rest_url(rest_command.path))
      elsif rest_command.kind_of?(Command::RestCall::Delete)
        delete(rest_url(rest_command.path))
      else
        raise ErrorUsage.new("Unexpected Rest Command type: #{rest_command.class}")
      end      
    end

    class Error < ErrorUsage
      def initialize(response_not_ok,rest_command)
        error_print_form = error_print_form(response_not_ok)
        error_msg = "Bad Rest response from call (#{rest_command.input_hash.inspect}:\n #{error_print_form}"
        super(error_msg)
      end
     private
      def error_print_form(response_not_ok)
        ret_obj = 
          if errors = response_not_ok['errors']
            errors.size == 1 ? errors.first : errors
           else
            response_not_ok
          end
        ret_obj.kind_of?(String) ? ret_obj : ret_obj.inspect
      end
    end

  end
end; end

