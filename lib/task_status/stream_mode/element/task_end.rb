module DTK::Client; class TaskStatus::StreamMode
  class Element
    class TaskEnd < self
      def task_end?()
        true
      end

      def render
        return if @ignore_stage_level_info
        msg = "end: '#{field?(:display_name) || 'Workflow'}'"
        if duration = formatted_duration?
          msg << " (total duration: #{duration})"
        end
        render_line msg, :bracket => true
      end
    end
  end
end; end

