class DTK::Client::Execute
  class Command::APICall
    class V1 < self
      RoutePrefix = 'api/v1'

      dtk_require('v1/services')
      
      def raw_executable_commands(&block)
        method = required(:method).to_sym
        object_type = required(:object_type).to_sym
        case object_type
         when :services
          Services.raw_executable_commands(method,&block)
         else
          raise ErrorUsage.new("The object_type '#{object_type}' is not supported in v1 api")
        end
      end

    end
  end
end
