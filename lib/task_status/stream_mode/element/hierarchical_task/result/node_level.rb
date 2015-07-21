module DTK::Client; class TaskStatus::StreamMode::Element::HierarchicalTask
  class Results
    class NodeLevel < self
      def render_results(results_per_node)
        results_per_node.each { |result| result.render }
      end
      
      def render
        render_node_errors
      end
    end
  end
end; end
