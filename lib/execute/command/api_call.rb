class DTK::Client::Execute
  class Command
    class APICall < self

      # order matters
      def self.Required(key)
        Required.new(key)
      end
      def self.PreviousResponse(key)
        # TODO: stub
        Required.new(key)
      end
      dtk_require('api_call/translation_term')
      dtk_require('api_call/map')
      dtk_require('api_call/service')

      attr_reader :executable_commands
      def initialize(hash)
        super
        object_type = required(:object_type)
        @executable_commands = ret_executable_commands(required(:object_type),required(:method),optional?(:params))
      end

     private
       # returns the one or more commands that achieve the api
      def ret_executable_commands(object_type,method,params={})
        case object_type.to_sym
         when :service
          Service.objects_executable_commands(method,params)
         else
          raise ErrorUsage.new("The object_type '#{object_type}' is not supported")
        end
      end

      def self.objects_executable_commands(method,params)
        method = method.to_sym
        if command_map = self::CommandMap[method]
          array_form(command_map).map{|command|command.translate(params)}
        elsif self::CustomMapping.methods(false).include?(method)
          array_form(self::CustomMapping.send(method,params))
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
