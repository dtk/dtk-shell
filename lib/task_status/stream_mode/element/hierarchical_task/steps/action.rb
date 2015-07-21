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

