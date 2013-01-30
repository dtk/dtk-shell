##
# Application expected errors will be handled trough DtkError. All else will be treaded 
# as Internal Server error. Logs will be added to ~/dtk.log for developers to investigate
# issues more closely.

module DTK
  module Client
    class Error < NameError
    end

    class DtkValidationError < Error
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
