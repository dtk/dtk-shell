module DTK::Client; class TaskStatus::StreamMode::Element
  class HierarchicalTask 
    class Results < self
      require File.expand_path('result/action', File.dirname(__FILE__))
      require File.expand_path('result/components', File.dirname(__FILE__))

      def self.render(element, stage_subtasks)
        results_per_node = base_subtasks(element, stage_subtasks)
        return if results_per_node.empty?
        # assumption is that if multipe results_per_node they are same type
        results_per_node.first.render_results(results_per_node)
      end
      
      private
      
      def self.create(element, hash)
        action_mode?(hash) ? Action.new(element, hash) : Components.new(element, hash)
      end

    end
  end
end; end
