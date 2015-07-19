module DTK::Client; class TaskStatus::StreamMode::Element
  module HierarchicalTask 
    class BaseSubtask
      def initialize(element, hash)
        @element       = element
        @type          = self.class.type(hash),
        @node_name     = (hash['node'] || {})['name']
        @is_node_group = HierarchicalTask.has_node_group?(hash)
      end
      
      private
      
      def render_line(*args)
        @element.render_line(*args)
      end

      def render_empty_line
        @element.render_empty_line
      end

      def node_term?
        if @node_name
          ret = ''
          if @is_node_group
            ret << 'node-group:'
          end
          if @node_name
            ret << @node_name
          end
          ret.nil? ? nil : ret
        end
      end
      
      def self.type(hash)
        hash['executable_action_type']
      end

      def self.action_mode?(hash)
        type(hash) == ComponentActionType
      end
      ComponentActionType = 'ComponentAction'
    end
  end
end; end


