module DTK::Client; class TaskStatus::StreamMode
  class Element
    class TaskStart < self
      def self.get(task_status_handle)
        get_task_status_elements(task_status_handle, :task_start, :start_index => 0, :end_index => 0)
      end

      def render
        msg = "Start '#{field?(:display_name) || 'Workflow'}'"
        render_line @render_opts.bracketed_msg(msg, :started_at => field?(:started_at))
      end
    end
  end
end; end

