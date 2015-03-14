class DTK::Client::Execute
  class Command::APICall
    class TranslationTerm
      def self.matches?(obj)
        obj.kind_of?(self) or
        (obj.kind_of?(Class) and obj <= self)
      end

      def self.instance_form()
        new()
      end
      def instance_form()
        self
      end
    end

    class Rest < TranslationTerm
      class Post < self
      end
    end

    class Equal < TranslationTerm
      def translate(key,api_params)
        api_params[key]
      end

      class Required < self
        def translate(key,api_params)
          unless api_params.has_key?(key)
            raise ErrorUsage.new("Missing key '#{key}' in params: #{api_params.inspect}")
          end
          api_params[key]
        end
      end

      def self.OrDefault(default_value)
        OrDefault.new(default_value)
      end
      class OrDefault < self
        def initialize(default_value)
          @default_value = default_value
        end
        def translate(key,api_params)
          api_params.has_key?(key) ? api_params[key] : @default_value
        end
      end
    end

  end
end

