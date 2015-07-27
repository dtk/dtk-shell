module DTK::Client; class TaskStatus::StreamMode::Element
  class HierarchicalTask 
    require File.expand_path('hierarchical_task/result', File.dirname(__FILE__))
    require File.expand_path('hierarchical_task/steps', File.dirname(__FILE__))

    def initialize(element, hash)
      @type          = self.class.type(hash)
      @element       = element
      @node_name     = (hash['node'] || {})['name']
      @is_node_group = self.class.has_node_group?(hash)
    end

    def self.render_results(element, stage_subtasks)
      stage_subtasks && Results.render(element, stage_subtasks)
    end

    def self.render_steps(element, stage_subtasks)
      stage_subtasks && Steps.render(element, stage_subtasks)
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

    def self.create(element, hash)
      stage_type_class(hash).new(element, hash)
    end

    def self.type(hash)
      hash['executable_action_type']
    end

    def self.stage_type_class(hash) 
      case type(hash)
        when 'ComponentAction'
          self::Action
        when 'ConfigNode'
          self::Components
        else # they will be node level
          self::NodeLevel
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

    def render_node_term(opts = {})
      if @node_name
        if @is_node_group 
          render_line("NODE-GROUP: #{@node_name}", opts)
        else
          render_line("NODE: #{@node_name}", opts)
        end
      end
    end

    def node_term?
      if @node_name
        @is_node_group ? "node-group:#{@node_name}" : @node_name
      end
    end
  end
end; end
