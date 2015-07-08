module DTK::Client; class TaskStatus::StreamMode
  class Element
    require File.expand_path('element/task_start',File.dirname(__FILE__))
    require File.expand_path('element/task_end',File.dirname(__FILE__))
    require File.expand_path('element/stage',File.dirname(__FILE__))
    require File.expand_path('element/render',File.dirname(__FILE__))
    include RenderMixin

    def initialize(response)
      @response = response
    end
    
    def self.get_task_start(task_status_handle)
      TaskStart.get(task_status_handle)
    end

    def self.get_stage(task_status_handle,stage)
      Stage.get(task_status_handle,stage)
    end

    def self.render_elements(elements)
      elements.map{|el|el.render()}
    end
    def render()
      #TODO: stub
      pp [:element,self.class,self]
    end

    # ovewritten
    def task_end?()
      #TODO: stub
    end

    private
    # opts will have
    #  :start_index
    #  :end_index
    def self.get_task_status_elements(task_status_handle,element_type,opts={})
      response = task_status_handle.post_call(opts.merge(:form => :stream_form))
      create_elements(element_type,response)
    end

    def self.create_elements(element_type,response)
      # TODO: stub
      [create(element_type,response)]
    end

    def self.create(element_type,response)
      case element_type
      when :task_start then TaskStart.new(response)
      when :stage then Stage.new(response)
      else raise DtkError::Client.new("Unexpected element_type '#{element_type}'")
      end
    end
  end
end; end
