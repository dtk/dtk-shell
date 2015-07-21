module DTK::Client; class TaskStatus::StreamMode::Element
  class HierarchicalTask 
    class Results < self
      require File.expand_path('result/action', File.dirname(__FILE__))
      require File.expand_path('result/components', File.dirname(__FILE__))
      require File.expand_path('result/node_level', File.dirname(__FILE__))

      def initialize(element, hash)
        super
        @errors = hash['errors'] || []
      end


      def self.render(element, stage_subtasks)
        results_per_node = base_subtasks(element, stage_subtasks)
        return if results_per_node.empty?
        # assumption is that if multipe results_per_node they are same type
        results_per_node.first.render_results(results_per_node)
      end

      private
      
      def render_node_errors
        unless @errors.empty?
          render_node_term
          @errors.each { |error| render_error_lines(error) }
          render_empty_line
        end
      end

      def render_error_lines(error)
        #TODO stub
        pp [:error,error]
      end

    end
  end
end; end
