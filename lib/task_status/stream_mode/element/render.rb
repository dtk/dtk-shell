#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
class DTK::Client::TaskStatus::StreamMode::Element
  module RenderMixin
    def render_line(msg, params = {})
      if msg
        print_to_console(@formatter.format(msg, params))
        render_empty_line
      end
    end
    
    def render_start_time(started_at)
      render_line(@formatter.start_time_msg?(started_at))
    end
    
    def formatted_duration?
      @formatter.formatted_duration?(field?(:duration))
    end

    def render_duration_line
      render_line(@formatter.duration_msg?(field?(:duration)))
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
