class DTK::Client::TaskStatus::StreamMode::Element::Stage
  module RenderMixin
    def render
      render_start unless @just_render and @just_render != :start
      render_end unless @just_render and @just_render != :end
    end
    
    private
      
    def render_start
      render_border
      render_line line__stage_heading
      render_start_time? field?(:started_at)
    end
    
    def render_end
      render_line line__status
      render_duration? field?(:duration)
      render_border
      render_empty_line
    end
  
    def line__stage_heading
      msg = 'STAGE: '
      if stage_num  = field?(:position)
        msg << " #{stage_num.to_s} "
      end
      if stage_name = stage_name?
        msg << " '#{stage_name}' "
      end
      msg
    end
    
    def line__status
      "STATUS: #{field?(:status) || 'UNKNOWN'}"
    end
    
    def stage_name?
      field?(:display_name)
    end
    
  end
end
=begin
===============================================================
ACTION: <action path/name>
TIME START: 2015-07-17 01:21:28 +0000S
DURATION: 40s
STATUS: succeeded
=end
