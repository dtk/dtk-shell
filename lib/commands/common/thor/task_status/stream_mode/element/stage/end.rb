class DTK::Client::TaskStatus::StreamMode::Element
  class Stage
    module EndMixin
      def render_end
        render_line msg__status
        render_line msg__end
        render_space
      end

      private

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

    end
  end
end

