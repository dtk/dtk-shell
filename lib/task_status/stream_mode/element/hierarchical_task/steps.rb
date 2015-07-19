module DTK::Client; class TaskStatus::StreamMode::Element
  module HierarchicalTask 
    class Steps < BaseSubtask
      def initialize(element, hash)
        super
        @action           = hash['action'] if action_mode?    
        @component_names  = ret_component_names(hash) if !action_mode?
      end
      
      private

      def ret_component_names(hash)
        (hash['components'] || []).map { |cmp| cmp['name'] }.compact
      end
    end
  end
end; end
