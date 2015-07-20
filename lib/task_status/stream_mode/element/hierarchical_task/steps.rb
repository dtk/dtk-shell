module DTK::Client; class TaskStatus::StreamMode::Element
  class HierarchicalTask 
    class Steps < self
      private

      def self.render(element, stage_subtasks)
        steps = base_subtasks(element, stage_subtasks, :stop_at_node_group => true)
        steps.each { |step| step.render }
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
          @action = hash['action'] || {}
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

      class Components < self
        def initialize(element, hash)
          super
          pp [:component_steps, hash]
          @component_names = (hash['components'] || []).map { |cmp| cmp['name'] }.compact
        end
        
        def render
          
        end
      end

    end
  end
end; end
