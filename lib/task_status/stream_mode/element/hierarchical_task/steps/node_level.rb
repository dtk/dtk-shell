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
