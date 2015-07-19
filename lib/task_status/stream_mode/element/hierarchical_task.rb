module DTK::Client; class TaskStatus::StreamMode::Element
  module HierarchicalTask 
    require File.expand_path('hierarchical_task/base_subtask', File.dirname(__FILE__))
    # base_subtask must be below
    require File.expand_path('hierarchical_task/result', File.dirname(__FILE__))
    require File.expand_path('hierarchical_task/steps', File.dirname(__FILE__))

    def self.render_steps(element, stage_subtasks)
      steps = base_subtasks(Steps, element, stage_subtasks, :stop_at_node_group => true)
      steps.each { |step| step.render }
    end

    def self.render_results(element, stage_subtasks)
      results = base_subtasks(Results, element, stage_subtasks)
      results.each { |result| result.render }
    end

    def self.has_node_group?(subtask_hash)
      subtask_hash['node'] and subtask_hash['node']['type'] == 'group'
    end

    private
    
    def self.base_subtasks(klass, element, stage_subtasks, opts = {})
      stage_subtasks.inject([]) do |a, subtask_hash|
        if opts[:stop_at_node_group] and has_node_group?(subtask_hash)
          a + [klass.create(element, subtask_hash)]
        elsif (subtask_hash['subtasks'] || []).empty?
          a + [klass.create(element, subtask_hash)]
        else
          a + base_subtasks(klass, element, subtask_hash['subtasks'], opts)
        end
      end
    end

  end
end; end
