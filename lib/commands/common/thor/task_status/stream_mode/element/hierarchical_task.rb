# TODO: when this simplication becomes stable, more to server side
module DTK::Client; class TaskStatus::StreamMode::Element
  module HierarchicalTask 
    def self.steps(stage_subtasks)
      base_subtasks(Steps, stage_subtasks, :stop_at_node_group => true)
    end

    def self.results?(stage_subtasks)
      base_subtasks(Results, stage_subtasks)
    end

    def self.has_node_group?(subtask_hash)
      subtask_hash['node'] and subtask_hash['node']['type'] == 'group'
    end

    private
    
    def self.base_subtasks(klass, stage_subtasks, opts = {})
      stage_subtasks.inject([]) do |a, subtask_hash|
        if opts[:stop_at_node_group] and has_node_group?(subtask_hash)
          a + [klass.new(subtask_hash)]
        elsif (subtask_hash['subtasks'] || []).empty?
          a + [klass.new(subtask_hash)]
        else
          a + base_subtasks(klass, subtask_hash['subtasks'], opts)
        end
      end
    end

    class BaseSubtask
      def initialize(hash)
        @type          = hash['executable_action_type']
        @node_name     = (hash['node'] || {})['name']
        @is_node_group = HierarchicalTask.has_node_group?(hash)
      end

      def action_mode?
        @type == 'ComponentAction'
      end
    end

    class Steps < BaseSubtask
      def initialize(hash)
        super
        @action           = hash['action'] if action_mode?    
        @component_names  = ret_component_names(hash) if !action_mode?
      end
      
      private

      def ret_component_names(hash)
        (hash['components'] || []).map { |cmp| cmp['name'] }.compact
      end
    end
    
    class Results < BaseSubtask
      def initialize(hash)
        super
        @action_results = hash['action_results'] if action_mode?
        @errors         = hash['errors'] if !action_mode?
      end

      attr_reader :action_results, :errors
    end
  end
end; end
