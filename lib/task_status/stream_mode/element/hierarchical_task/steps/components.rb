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
    class Components < self
      def initialize(element, hash)
        super
        @component_names = (hash['components'] || []).map { |cmp| cmp['name'] }.compact
      end

      attr_reader :component_names

      def render_steps(steps)
        step = steps.first
        if steps.size ==  1 and step.component_names.size == 1 
          render_line "COMPONENT: #{step.component_term(step.component_names.first)}"
        else
          render_line 'COMPONENTS:'
          steps.each do |step| 
            step.component_names.each do |component_name|
              render_line  step.component_term(component_name), :tabs => 1
            end
          end
        end
      end
      
      def component_term(component_name)
        ret = ''
        if node_term = node_term?
          ret << "#{node_term}/"
        end
        ret << component_name
        ret
      end
    end
  end

end; end
