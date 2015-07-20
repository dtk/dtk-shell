module DTK::Client; class TaskStatus::StreamMode::Element::HierarchicalTask
  class Results
    class Components < self
      def initialize(element, hash)
        super
        @errors = hash['errors'] || []
      end
      
      def render_results(results_per_node)
        results_per_node.each { |result| result.render }
      end
      
      def render
        render_node_term?
        @errors.each { |error| render_error_lines(error) }
      end
      
      private
      
      def render_error_lines(error)
        #TODO stub
        pp [:error,error]
      end

    end
  end
end; end
