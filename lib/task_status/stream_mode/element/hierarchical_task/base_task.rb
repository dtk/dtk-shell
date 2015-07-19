module DTK::Client; class TaskStatus::StreamMode::Element
  module HierarchicalTask 
    class BaseSubtask
      def initialize(element, hash)
        @element       = element
        @type          = hash['executable_action_type']
        @node_name     = (hash['node'] || {})['name']
        @is_node_group = HierarchicalTask.has_node_group?(hash)
      end
      
      # can be overwritten
      def self.create(element, hash)
        new(element, hash)
      end

      private

      def render_line(*args)
        @element.render_line(*args)
      end

      def self.action_mode?(type)
        @type == ComponentActionType
      end
      ComponentActionType = 'ComponentAction'

    end
  end
end

