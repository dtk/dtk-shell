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
    class Results < self
      require File.expand_path('result/action', File.dirname(__FILE__))
      require File.expand_path('result/components', File.dirname(__FILE__))
      require File.expand_path('result/node_level', File.dirname(__FILE__))

      def initialize(element, hash)
        super
        @errors = hash['errors'] || []
      end


      def self.render(element, stage_subtasks)
        results_per_node = base_subtasks(element, stage_subtasks)
        return if results_per_node.empty?
        # assumption is that if multipe results_per_node they are same type
        results_per_node.first.render_results(results_per_node)
      end

      protected 

      attr_reader :errors

      def render_errors(results_per_node)
        return unless results_per_node.find { |result| not result.errors.empty?}
        first_time = true
        results_per_node.each do |result| 
          if first_time
            render_line 'ERRORS:' 
            first_time = false
          end
          result.render_node_errors  
        end
      end

      def render_node_errors
        return if @errors.empty?
        render_node_term
        @errors.each do |error| 
          if err_msg = error['message']
            render_error_line err_msg  
            render_empty_line
          end
        end
      end

      def render_error_line(line, opts = {})
        render_line(line, ErrorRenderOpts.merge(opts))
      end
      ErrorRenderOpts = { :tabs => 1}
      
    end
  end
end; end