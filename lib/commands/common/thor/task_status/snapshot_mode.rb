module DTK::Client
  class TaskStatus
    class SnapshotMode < self
      def task_status(opts={})
        response = task_status_post_call(opts)
        response.print_error_table = true
        response.render_table(:task_status)
      end
    end
  end
end