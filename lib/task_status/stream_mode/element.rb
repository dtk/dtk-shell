module DTK::Client; class TaskStatus::StreamMode
  class Element
    require File.expand_path('element/format', File.dirname(__FILE__))
    require File.expand_path('element/render', File.dirname(__FILE__))
    require File.expand_path('element/hierarchical_task', File.dirname(__FILE__))
    require File.expand_path('element/task_start', File.dirname(__FILE__))
    require File.expand_path('element/task_end', File.dirname(__FILE__))
    require File.expand_path('element/stage', File.dirname(__FILE__))
    require File.expand_path('element/no_results', File.dirname(__FILE__))
    include RenderMixin

    def initialize(response_element, opts = {})
      @response_element    = response_element
      @formatter          = Format.new(response_element['type'])
      @ignore_stage_level_info = opts[:ignore_stage_level_info]
    end

    def self.get_and_render_task_start(task_status_handle, opts = {})
      render_elements(TaskStart.get(task_status_handle, opts))
    end

    def self.get_and_render_stages(task_status_handle, opts = {})
      Stage.get_and_render_stages(task_status_handle, opts)
    end

    private

    # opts will have
    #   :start_index
    #   :end_index
    # opts can have
    #   :ignore_stage_level_info - Boolean
    def self.get_task_status_elements(task_status_handle, element_type, opts = {})
      response =  task_status_handle.post_call(opts.merge(:form => :stream_form))
      create_elements(response, opts)
    end

    # opts can have
    #   :ignore_stage_level_info - Boolean
    def self.create_elements(response, opts = {})
      response_elements = response.data
      unless response_elements.kind_of?(Array)
        raise DtkError::Client.new("Unexpected that response.data no at array")
      end
      response_elements.map { |el| create(el, opts) }
    end
    def self.create(response_element, opts)
      type = response_element['type'] 
      case type && type.to_sym
        when :task_start  then TaskStart.new(response_element, opts)
        when :task_end    then TaskEnd.new(response_element, opts)
        when :stage       then Stage.new(response_element, opts)
        when :stage_start then Stage.new(response_element, {:just_render => :start}.merge(opts))
        when :stage_end   then Stage.new(response_element, {:just_render => :end}.merge(opts))
        when :no_results  then NoResults.new(response_element, opts)
        else              raise DtkError::Client.new("Unexpected element type '#{type}'")
      end
    end
    
    def self.task_end?(elements)
      elements.empty? or elements.last.kind_of?(TaskEnd)
    end
    
    def self.no_results_yet?(elements)
      elements.find{|el|el.kind_of?(NoResults)}
    end

    def self.render_elements(elements)
      elements.each{ |el| el.render }
    end

    def render_stage_steps(subtasks)
      HierarchicalTask.render_steps(self, subtasks)
    end

    def render_stage_results(subtasks)
      HierarchicalTask.render_results(self, subtasks)
    end

    def field?(field)
      @response_element[field.to_s]
    end
  end
end; end

