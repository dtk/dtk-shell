##
# Application expected errors will be handled trough DtkError. All else will be treaded 
# as Internal Server error. Logs will be added to ~/dtk.log for developers to investigate
# issues more closely.

module DTK
  module Client
    class Error < NameError
    end

   # DtkError is child of Error; so order matters
    require File.expand_path('dtk_error', File.dirname(__FILE__))

    class DSLParsing < Error
      def initialize(base_json_error,file_path=nil)
        super(err_msg(base_json_error,file_path))
      end
      private
      def err_msg(base_json_error,file_path=nil)
        "#{base_json_error}: #{file_path}"
      end

      class JSONParsing < self
      end

      class YAMLParsing < self
      end
    end

    # class DtkValidationError < Error

    #   attr_accessor :skip_usage_info

    #   def initialize(msg, skip_usage_info = false)
    #     @skip_usage_info = skip_usage_info
    #     super(msg)
    #   end
    # end

    class DtkValidationError < Error

      attr_accessor :display_usage_info

      def initialize(msg, display_usage_info = false)
        @display_usage_info = display_usage_info
        super(msg)
      end
    end

    # raise by developers to signal wrong usage of components
    class DtkImplementationError < Error
    end

    class DtkLoginRequiredError < Error
    end

  end
end

module DTK
  module Shell
    class Error < DTK::Client::Error
    end

    class ExitSignal < DTK::Client::Error
    end
  end
end
