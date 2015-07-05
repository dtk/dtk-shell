module DTK::Client; class TaskStatus
  class StreamMode
    class Element
      def initialize(response)
        @response = response
      end

      def self.create(element_type,response)
        case element_type
          when :task_start then TaskStart.new(response)
          when :stage then Stage.new(response)
          else raise DtkError, "[CLIENT ERROR] Unexpected element_type '#{element_type}'"
        end
      end
    end
  end
end; end
