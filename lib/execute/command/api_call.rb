class DTK::Client::Execute
  class Command
    class APICall < self

      # order matters; having these defs before requires; plus order of these requires
      def self.Required(key)
        Required.new(key)
      end
      def self.PreviousResponse(response_key)
        PreviousResponse.new(response_key)
      end
      dtk_require('api_call/translation_term')
      dtk_require('api_call/map')
      dtk_require('api_call/service')


       # calss block where on one or more commands that achieve the api
      def raw_executable_commands(&block)
        method = required(:method).to_sym
        case required(:object_type).to_sym
         when :service
           Service.raw_executable_commands(method,&block)
         else
          raise ErrorUsage.new("The object_type '#{object_type}' is not supported")
        end
      end

     private
      def self.raw_executable_commands(method,&block)
        if command_map = self::CommandMap[method]
          array_form(command_map).each{|raw_command|block.call(raw_command)}
        else
          raise ErrorUsage.new("The method on '#{method}' on object type '#{object_type()}' is not supported")
        end
      end

      def self.array_form(obj)
        obj.kind_of?(Array) ? obj : [obj]
      end

    end
  end
end
