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
  class Results
    class Action < self
      def initialize(element, hash)
        super
        @action_results = hash['action_results'] || [] 
      end

      attr_reader :action_results
      
      def render_results(results_per_node)
        if any_results?(results_per_node)
          render_line 'RESULTS:'
          render_empty_line
          results_per_node.each { |result| result.render }
        else
          render_errors(results_per_node)
        end
      end

      def render
        not_first_time = nil
        render_node_term
        @action_results.each do |action_result| 
          render_action_result_lines(action_result, :first_time => not_first_time.nil?) 
          not_first_time ||= true
        end
        render_empty_line
      end

      private

      def any_results?(results_per_node)
        !!results_per_node.find { |results| !results.action_results.empty? }
      end

      def render_action_result_lines(action_result, opts = {})
        stdout = action_result['stdout']
        stderr = action_result['stderr']
        unless opts[:first_time]
          render_line '--' 
        end
        if command = command?(action_result)
          render_line command 
        end
        if return_code = action_result['status']
          render_line "RETURN CODE: #{return_code.to_s}"
        end
        if stdout && !stdout.empty?
          render_line 'STDOUT:'
          render_action_output stdout
        end
        if stderr && !stderr.empty?        
          render_line 'STDERR:'
          render_action_output stderr
        end
      end
      
      def render_action_output(line)
        render_line line, RenderActionLineOpts
      end
      RenderActionLineOpts = { :tabs => 1 }
      
      def command?(action_result)
        if command = action_result['description']
          if match = command.match(/^(create )(.*)/)
            "ADD: #{match[2]}"
          else
            "RUN: #{command}"
          end
        end
      end
      
    end
  end
end; end
