module DTK::Client; class TaskStatus::StreamMode
  class Element
    require File.expand_path('element/render', File.dirname(__FILE__))
    require File.expand_path('element/task_start', File.dirname(__FILE__))
    require File.expand_path('element/task_end', File.dirname(__FILE__))
    require File.expand_path('element/stage', File.dirname(__FILE__))
    require File.expand_path('element/no_results', File.dirname(__FILE__))
    include Render::Mixin

    def initialize(response_element)
      @response_element = response_element
      # TODO: hard coded now
      @render_opts = Render::Opts.new(response_element['type'])
    end

    def self.get_and_render_task_start(task_status_handle)
      render_elements(TaskStart.get(task_status_handle))
    end

    def self.get_and_render_stages(task_status_handle, opts = {})
      Stage.get_and_render_stages(task_status_handle, opts)
    end

    # TODO: for debugging
    def render
      pp self
    end

    private

    # opts will have
    #   :start_index
    #   :end_index
    def self.get_task_status_elements(task_status_handle, element_type, opts = {})
      response =  task_status_handle.post_call(opts.merge(:form => :stream_form))
      create_elements(response)
    end

    def self.create_elements(response)
      response_elements = response.data
      unless response_elements.kind_of?(Array)
        raise DtkError::Client.new("Unexpected that response.data no at array")
      end
      response_elements.map{|el|create(el)}
    end
    def self.create(response_element)
      type = response_element['type'] 
      case type && type.to_sym
        when :task_start  then TaskStart.new(response_element)
        when :task_end    then TaskEnd.new(response_element)
        when :stage       then Stage.new(response_element)
        when :stage_start then Stage.new(response_element, :just_render => :start)
        when :stage_end   then Stage.new(response_element, :just_render => :end)
        when :no_results  then NoResults.new(response_element)
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

    def field?(field)
      @response_element[field.to_s]
    end

    # render related
    def render_line(msg, params = {})
      print_to_console(@render_opts.format(msg, params))
      render_empty_line
    end     

    def render_line?(msg, params = {})
      if msg
        render_line(msg, params)
      end
    end

    def render_start_time?(started_at)
      render_line(@render_opts.start_time_msg?(started_at))
    end

    def render_duration?(duration)
      render_line(@render_opts.duration_msg?(duration))
    end

    def render_border
      print_to_console(@render_opts.border)
      render_empty_line
    end     

    def render_empty_line
      render_empty_lines(1)
    end

    def render_empty_lines(num_empty_lines = 1)
      print_to_console("\n" * num_empty_lines)
    end

  end
end; end
