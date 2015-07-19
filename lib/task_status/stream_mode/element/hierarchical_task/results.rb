module DTK::Client; class TaskStatus::StreamMode::Element
  module HierarchicalTask 
    class Results < BaseSubtask
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
          @action_results.each | action_result| render_action_result_lines(action_result)
        end
        
        private
        
        def render_action_result_lines(action_result)
          description = description?(action_result)
          return_code = action_result['status']
          stdout      = action_result['stdout']
          stderr      = action_result['stderr']
          render_line '--' 
          if description
            render_line description 
          end
          if return_code
            render_line "STATUS: #{return_code}"
          end
          if stdout && !stdout.empty?
            render_line "STDOUT: #{stdout}"
          end
          if stderr && !stderr.empty?        
            render_line "STDERR: #{stderr}"
          end
          ret
        end
        
        def .description?(action_result)
          if description = action_result['description']
            if match = description.match(/^(create )(.*)/)
              "ADD: #{match[2]}"
            else
              "RUN: #{description}"
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
