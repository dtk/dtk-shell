module DTK::Client; class TaskStatus::StreamMode
  class Element
    class Stage < self
      def self.get(task_status_handle,stage_num)
        get_stages(task_status_handle,stage_num,stage_num)
      end

      def self.get_stages(task_status_handle,start_stage_num,end_stage_num)
        get_task_status_elements(task_status_handle,:stage,:start_index => start_stage_num, :end_index => end_stage_num)
      end

      def render
        render_line msg__start
        render_line msg__status
        render_line msg__end
        render_space
      end

      def msg__start
        msg = 'start stage'
        if stage_num  = field?(:position)
          msg << " #{stage_num.to_s} "
        end
        if stage_name = stage_name?
          msg << " '#{stage_name}' "
        end
        @render_opts.msg(msg, :bracket => true, :started_at => field?(:started_at))
      end

      def msg__status
        msg = "status: #{field?(:status) || 'UNKNOWN'}"
        @render_opts.msg(msg)
      end

      def msg__end
        msg = "end: "
        if stage_name = stage_name?
          msg << " '#{stage_name}' "
        end
        @render_opts.msg(msg, :bracket => true, :duration => field?(:duration))
      end

      def stage_name?
        field?(:display_name)
      end
    end
  end
end; end
