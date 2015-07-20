module DTK::Client; class TaskStatus::StreamMode::Element::HierarchicalTask
  class Results
    class Action < self
      def initialize(element, hash)
        super
        @action_results = hash['action_results'] || [] 
      end
      
      def render_results(results_per_node)
        render_line 'RESULTS:'
        render_empty_line
        results_per_node.each { |result| result.render }
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
