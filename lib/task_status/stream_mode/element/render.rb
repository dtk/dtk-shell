class DTK::Client::TaskStatus::StreamMode::Element
  module RenderMixin

    def render_line(msg, params = {})
      print_to_console(@formatter.format(msg, params))
      render_empty_line
    end     

    def render_line?(msg, params = {})
      if msg
        render_line(msg, params)
      end
    end
    
    def render_start_time?(started_at)
      render_line(@formatter.start_time_msg?(started_at))
    end
    
    def formatted_duration?
      @formatter.formatted_duration?(field?(:duration))
    end

    def render_duration_line?
      render_line?(@formatter.duration_msg?(field?(:duration)))
    end
  
    def render_border
      print_to_console(@formatter.border)
      render_empty_line
    end     
    
    def render_empty_line
      render_empty_lines(1)
    end
    
    def render_empty_lines(num_empty_lines = 1)
      print_to_console("\n" * num_empty_lines)
    end

    private

    def print_to_console(string)
      #TODO: stub
      STDOUT << string
    end
  end
end
