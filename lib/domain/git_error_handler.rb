
module DTK
  module Client

    class GitHandledException < Exception
      def initialize(msg, backtrace)
        super(msg)
        set_backtrace(backtrace)
      end
    end

    class GitErrorHandler

      # due to problems with git logging messages which are not user friendly we are going to wrap their error and try to produce more readable results
      def self.handle(exception)
        handled_exception = exception

        if exception.is_a? Git::GitExecuteError
          error_message = user_friendly_message(exception.message)
          handled_exception = GitHandledException.new(error_message, exception.backtrace)
        end

        handled_exception
      end

    private

      def self.user_friendly_message(message)
        case message
        when /repository not found/i
          "Repository not found"
        when /repository (.*) not found/i
          "Repository #{$1.strip()} not found"
        when /destination path (.*) already exists/i
          "Destination folder #{$1.strip()} already exists"
        when /Authentication failed for (.*)$/i
          "Authentication failed for given repository #{$1.strip()}"
        when /timed out/
          "Timeout - not able to contact remote"
        else
          message
        end
      end

    end
  end
end