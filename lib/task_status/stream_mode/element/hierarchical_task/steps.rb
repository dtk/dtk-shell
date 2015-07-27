module DTK::Client; class TaskStatus::StreamMode::Element
  class HierarchicalTask 
    class Steps < self
      require File.expand_path('steps/action', File.dirname(__FILE__))
      require File.expand_path('steps/components', File.dirname(__FILE__))
      require File.expand_path('steps/node_level', File.dirname(__FILE__))
    
      private

      def self.render(element, stage_subtasks)
        steps = base_subtasks(element, stage_subtasks, :stop_at_node_group => true)
        return if steps.empty?
        steps.first.render_steps(steps)
      end
    end
  end
end; end
