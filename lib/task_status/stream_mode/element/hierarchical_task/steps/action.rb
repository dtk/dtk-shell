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
    class Action < self
      def initialize(element, hash)
        super
        @action = hash['action'] || {}
      end

      def render_steps(steps)
        steps.each { |step| step.render }
      end

      def render
        if action_term = action_term?
          render_line "ACTION: #{action_term}"
        end
      end
      
      private
      
      def action_term?
        ret = ''
        if node_term = node_term?
          ret << "#{node_term}/"
        end
        if component_name = @action['component_name']
          ret << component_name
        end
        if method_name = @action['method_name']
          ret << ".#{method_name}"
        end
        ret.nil? ? nil : ret
      end
    end
  end
end; end
