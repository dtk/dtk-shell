module DTK::Client; class TaskStatus::StreamMode::Element::HierarchicalTask
  class Results
    class NodeLevel < self
      def render_results(results_per_node)
        render_errors(results_per_node)
      end
    end
  end
end; end
