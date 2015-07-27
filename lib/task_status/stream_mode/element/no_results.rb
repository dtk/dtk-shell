module DTK::Client; class TaskStatus::StreamMode
  class Element
    class NoResults < self
      def task_end?()
        true
      end
    end
  end
end; end

