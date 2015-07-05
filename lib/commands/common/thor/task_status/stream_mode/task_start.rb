module DTK::Client; class TaskStatus
  class StreamMode
    class TaskStart < Element
      def self.get(task_status_handle)
        task_status_handle.get_task_status_element(:task_start,:start_index => 0, :end_index => 0)
      end
    end
  end
end; end
