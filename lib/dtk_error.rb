module DTK
  module Client
    class DtkError < Error
      def initialize(msg,opts={})
        super(msg)
        @backtrace = opts[:backtrace]
      end
      attr_reader :backtrace

      def self.raise_error(response)
        raise_if_error?(response,:default_error => error_info_default())
      end
      def self.raise_if_error?(response,opts={})
        # check for errors in response
        unless error = error_info?(response) || opts[:default_error]
          return
        end
        
        # if error_internal.first == true
        case error.code
          when :unauthorized
            raise self, "[UNAUTHORIZED] Your session has been suspended, please log in again."
          when :session_timeout
            raise self, "[SESSION TIMEOUT] Your session has been suspended, please log in again."
          when :broken
            raise self, "[BROKEN] Unable to connect to the DTK server at host: #{Config[:server_host]}"
          when :forbidden
            raise DTK::Client::DtkLoginRequiredError, "[FORBIDDEN] Access not granted, please log in again."
          when :timeout
            raise self, "[TIMEOUT ERROR] Server is taking too long to respond."
          when :connection_refused
            raise self, "[CONNECTION REFUSED] Connection refused by server."
          when :resource_not_found
            raise self, "[RESOURCE NOT FOUND] #{error.msg}"
          when :pg_error
            raise self, "[PG_ERROR] #{error.msg}"
          when :server_error
            raise InternalError::Server.new(error.msg,:backtrace => error.backtrace)
          when :client_error
            raise InternalError::Client.new(error.msg,:backtrace => error.backtrace)
          else
          # if usage error occurred, display message to console and display that same message to log
            raise Usage.new(error.msg)
        end
      end

      SpecficErrorCodes = [:unauthorized,:session_timeout,:broken,:forbidden,:timeout,:connection_refused,:resource_not_found,:pg_error]
      DefaultErrorCode = :error
      DefaultErrorMsg = 'Internal DTK Client error, please try again'

      Info = Struct.new(:msg,:code,:backtrace)
      def self.error_info_default()
        Info.new(DefaultErrorMsg,DefaultErrorCode,nil)
      end

      # TODO: move to DTK::Response after clean up DTK::Response
      def self.error_info?(response)
        ret = nil
        if response["errors"].nil?
          return ret
        end

        error_msg       = ""
        error_internal  = nil
        error_backtrace = nil
        error_code      = nil
        error_on_server = nil
        #TODO:  below just 'captures' first error
        response_ruby_obj['errors'].each do |err|
          error_msg       +=  err["message"] unless err["message"].nil?
          error_msg       +=  err["error"]   unless err["error"].nil?
          error_on_server = true unless err["on_client"]
          error_code      = err["code"]||(err["errors"] && err["errors"].first["code"])
          error_internal  ||= (err["internal"] or error_code == "not_found") #"not_found" code is at Ramaze level; so error_internal not set
          error_backtrace ||= err["backtrace"]
        end

        # normalize it for display
        error_msg = error_msg.empty? ? DefaultErrorMsg : "#{error_msg}"

        unless error_code and SpecficErrorCodes.include?(error_code)
          error_code = 
            if error_internal
              error_on_server ? :server_error : :client_error
            else
              DefaultErrorCode
            end
        end
        
        error_code = error_code.to_sym
        Info.new(error_msg,error_code,error_backtrace)
      end

      class Usage < self
        def initialize(error_msg,opts={})
          msg_to_pass_to_super = "[ERROR] #{error_msg}"
          super(msg_to_pass_to_super,opts)
        end
      end

      class InternalError < self
        def initialize(error_msg,opts={})
          msg_to_pass_to_super = "[#{label(opts[:where])}] #{error_msg}"
          super(msg_to_pass_to_super,opts)
        end
        def self.label(where=nil)
          prefix = (where ? "#{where.to_s.upcase} " : '')
          "#{prefix}#{InternalErrorLabel}"
        end
        InternalErrorLabel = 'INTERNAL ERROR'
        class Client < self
          def initialize(error_msg,opts={})
            super(error_msg,opts.merge(:where => :client))
          end
          def self.label()
            super(:client)
          end
        end
        class Server < self
          def initialize(error_msg,opts={})
            super(error_msg,opts.merge(:where => :server))
          end
          def self.label()
            super(:server)
          end
        end

      end 
    end
  end
end
