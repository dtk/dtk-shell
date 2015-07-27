module DTK::Client; class TaskStatus::StreamMode
  class Element
    class TaskStart < self
      def self.get(task_status_handle, opts = {})
        opts_get = {
          :start_index => 0,
          :end_index   => 0
        }.merge(opts)
        get_task_status_elements(task_status_handle, :task_start, opts_get)
      end

      def render
        return if @ignore_stage_level_info
        msg = "start '#{field?(:display_name) || 'Workflow'}'"
        render_line msg, :bracket => true, :started_at => field?(:started_at)
        render_empty_lines 2
      end
    end
  end
end; end

