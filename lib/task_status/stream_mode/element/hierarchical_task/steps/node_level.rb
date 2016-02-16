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
module DTK::Client; class TaskStatus::StreamMode::Element::HierarchicalTask
  class Steps
    class NodeLevel < self
      def render_steps(steps)
        render_line node_operation_line(steps)
        steps.each { |step| step.render }
      end
      
      def render
        render_line node_term?, :tabs => 1
      end

      private

      def node_operation_line(steps)
        operation_term = @type
        if steps.size > 1 and not operation_term =~ /s$/
          operation_term += 's'
        end
        "OPERATION: #{operation_term}" 
      end

    end
  end
end; end
