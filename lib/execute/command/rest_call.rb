class DTK::Client::Execute
  class Command
    class RestCall < self
      # TODO: allow calls like 'converge' which is a macro; we either directly support or have a sub class of RestCall called macro
      attr_reader :path
      def initialize(hash)
        super
        @path = required(:path)
      end

      class Post < self
        attr_reader :body
        def initialize(hash)
          super
          @body = optional?(:body)||{}
        end
      end

      class Get < self
      end

      class Delete < self
      end
    end
  end
end
