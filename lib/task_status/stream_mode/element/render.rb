class DTK::Client::TaskStatus::StreamMode::Element
  module RenderMixin
    private 

    def render_line(msg, params = {})
      print_to_console(@formatter.format(msg, params))
      render_empty_line
    end     

    def render_lines(msg_array, params = {})
      msg_array.each { |msg| render_line(msg, params) }
    end     
    
    def render_line?(msg, params = {})
      if msg
        render_line(msg, params)
      end
    end
    
    def render_start_time?(started_at)
      render_line(@formatter.start_time_msg?(started_at))
    end
    
    def render_duration?(duration)
      render_line(@formatter.duration_msg?(duration))
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

    def print_to_console(string)
      #TODO: stub
      STDOUT << string
    end
  end
end
