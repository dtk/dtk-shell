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

    # we use this to log application errors
    class DtkError < Error
      def initialize(msg,opts={})
        super(msg)
        @backtrace = opts[:backtrace]
      end
      attr_reader :backtrace

      class InternalError < self
        def initialize(msg,opts={})
          msg_to_pass_to_super = "[#{label(opts[:where])}] #{error_msg}"
          super(msg_to_pass_to_super.opts)
        end
        def self.label(where=nil)
          prefix = (where ? "#{where.to_s.upcase} " : '')
          "#{prefix}#{InternalErrorLabel}"
        end
        InternalErrorLabel = 'INTERNAL ERROR'
        class Client < self
          def initialize(msg,opts={})
            super(msg,opts.merge(:where => :client))
          end
          def self.label()
            super(:client)
          end
        end
        class Server < self
          def initialize(msg,opts={})
            super(msg,opts.merge(:where => :server))
          end
          def self.label()
            super(:server)
          end
        end
      end 
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
