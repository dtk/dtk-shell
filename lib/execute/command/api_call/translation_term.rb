class DTK::Client::Execute
  class Command::APICall

    # abstract classes
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

      class Operation < self
      end

      class Param < self
       private
        def index(api_params,key)
          api_params[key]
        end

        def index_required(api_params,key)
          unless has_key?(api_params,key)
            raise ErrorUsage.new("Missing key '#{key}' in params: #{api_params.inspect}")
          end
          index(api_params,key)
        end

        def has_key?(api_params,key)
          api_params.has_key?(key)
        end

      end
    end

    # concrete classes

    class Rest < TranslationTerm::Operation
      class Post < self
      end
    end

    class Required < TranslationTerm::Param
      def initialize(input_key=nil)
        @input = input_key
      end

      def translate(key,api_params)
        index_required(api_params,@input||key)
      end

      class Equal < self
      end
    end

    class Equal < TranslationTerm::Param
      def translate(key,api_params)
        index(api_params,key)
      end

      class Required < self
        def translate(key,api_params)
          index_required(api_params,key)
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
          has_key?(api_params,key) ? index(api_params,key) : @default_value
        end
      end
    end

    class PreviousResponse < TranslationTerm::Param
      def initialize(response_key)
        @response_key = response_key
      end
    end
  end
end

