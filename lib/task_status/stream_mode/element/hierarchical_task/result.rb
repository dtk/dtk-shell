module DTK::Client; class TaskStatus::StreamMode::Element
  class HierarchicalTask 
    class Results < self
      def self.render(element, stage_subtasks)
        results = base_subtasks(element, stage_subtasks)
        results.each { |result| result.render }
      end

      private

      def self.create(element, hash)
        if action_mode?(hash)
          Action.new(element, hash)
        else
          Components.new(element, hash)
        end
      end
      
      class Action < self
        def initialize(element, hash)
          super
          @action_results = hash['action_results'] || [] 
        end
        
        def render
          render_line 'RESULTS:'
          render_empty_line
          not_first_time = nil
          @action_results.each do |action_result| 
            render_action_result_lines(action_result, :first_time => not_first_time.nil?) 
            not_first_time ||= true
          end
        end
        
        private
        
        def render_action_result_lines(action_result, opts = {})
          stdout      = action_result['stdout']
          stderr      = action_result['stderr']
          unless opts[:first_time]
            render_action_line '--' 
          end
          if command = command?(action_result)
            render_action_line command 
          end
          if status_term = status_term?(action_result)
            render_action_line "STATUS: #{status_term}"
          end
          if stdout && !stdout.empty?
            render_action_line "STDOUT: #{stdout}"
          end
          if stderr && !stderr.empty?        
            render_action_line "STDERR: #{stderr}"
          end
        end

        def render_action_line(line)
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

        def status_term?(action_result)
          if return_code = action_result['status']
            return_code = return_code.to_s
            if return_code == '0'
              "succeeded (0)"
            else
              "failed (#{return_code})"
            end
          end
        end
      end

      class Components < self
        def initialize(element, hash)
          super
          @errors = hash['errors'] || []
        end
        
        def render
          @errors.each { |error| render_error_lines(error) }
        end
        
        private
        
        def render_error_lines(error)
          #TODO stub
          pp [:error,error]
        end
      end

    end
  end
end; end
