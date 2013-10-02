##
# Application expected errors will be handled trough DtkError. All else will be treaded 
# as Internal Server error. Logs will be added to ~/dtk.log for developers to investigate
# issues more closely.

module DTK
  module Client
    class Error < NameError
    end

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

    class DtkValidationError < Error

      attr_accessor :skip_usage_info

      def initialize(msg, skip_usage_info = false)
        @skip_usage_info = skip_usage_info
        super(msg)
      end
    end

    # raise by developers to signal wrong usage of components
    class DtkImplementationError < Error
    end

    # we use this to log application errors
    class DtkError < Error
      def initialize(msg,opts={})
        super(msg)
        @backtrace = opts[:backtrace]
      end
      attr_reader :backtrace
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
