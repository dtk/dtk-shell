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
module DTK::Client; class TaskStatus::StreamMode::Element
  class HierarchicalTask 
    class Steps < self
      require File.expand_path('steps/action', File.dirname(__FILE__))
      require File.expand_path('steps/components', File.dirname(__FILE__))
      require File.expand_path('steps/node_level', File.dirname(__FILE__))
    
      private

      def self.render(element, stage_subtasks)
        steps = base_subtasks(element, stage_subtasks, :stop_at_node_group => true)
        return if steps.empty?
        steps.first.render_steps(steps)
      end
    end
  end
end; end