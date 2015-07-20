module DTK::Client; class TaskStatus::StreamMode::Element
  class HierarchicalTask 
    require File.expand_path('hierarchical_task/result', File.dirname(__FILE__))
    require File.expand_path('hierarchical_task/steps', File.dirname(__FILE__))

    def initialize(element, hash)
      @element       = element
      @type          = self.class.type(hash),
      @node_name     = (hash['node'] || {})['name']
      @is_node_group = has_node_group?(hash)
    end

    def self.render_results(element, stage_subtasks)
      Results.render(element, stage_subtasks)
    end

    def self.render_steps(element, stage_subtasks)
      Steps.render(element, stage_subtasks)
    end

    private

    def self.base_subtasks(element, stage_subtasks, opts = {})
      stage_subtasks.inject([]) do |a, subtask_hash|
        if opts[:stop_at_node_group] and has_node_group?(subtask_hash)
          a + [create(element, subtask_hash)]
        elsif (subtask_hash['subtasks'] || []).empty?
          a + [create(element, subtask_hash)]
        else
          a + base_subtasks(element, subtask_hash['subtasks'], opts)
        end
      end
    end      
    
    def self.has_node_group?(subtask_hash)
      subtask_hash['node'] and subtask_hash['node']['type'] == 'group'
    end

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
end; end
