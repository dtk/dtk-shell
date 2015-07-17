class DTK::Client::TaskStatus::StreamMode::Element
  class Stage
    module StartMixin
      def render_start
        render_line msg__start
      end
      
      private
      
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
    end
  end
end

