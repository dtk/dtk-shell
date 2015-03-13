class DTK::Client::Execute
  class Command
    class RestCall < self
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
    end
  end
end
