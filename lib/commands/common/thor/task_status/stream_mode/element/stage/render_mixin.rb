class DTK::Client::TaskStatus::StreamMode::Element::Stage
  module RenderMixin
    def render
      render_start unless @just_render and @just_render != :start
      render_end unless @just_render and @just_render != :end
    end
    
    private
    
    def render_start
      render_line msg__start
    end
    
    def render_end
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

