module DTK::Client; class TaskStatus::StreamMode
  class Element
    require File.expand_path('element/task_start',File.dirname(__FILE__))
    require File.expand_path('element/task_end',File.dirname(__FILE__))
    require File.expand_path('element/stage',File.dirname(__FILE__))
    require File.expand_path('element/no_results',File.dirname(__FILE__))
    require File.expand_path('element/render',File.dirname(__FILE__))
    include RenderMixin
    
    def initialize(response)
      @response = response
    end
    
    def self.create(element_type,response)
      case element_type
      when :task_start then TaskStart.new(response)
      when :task_end   then TaskEnd.new(response)
      when :stage      then Stage.new(response)
      when :no_results then NoResults.new(response)
      else raise DtkError::Client.new("Unexpected element_type '#{element_type}'")
      end
    end
    private_class_method :create

    def self.get_and_render_task_start(task_status_handle)
      render_elements(TaskStart.get(task_status_handle))
    end
    
    # opts has
    #  :wait - amount to wait if get no results (required)
    def self.get_and_render_stages(task_status_handle,opts={})
      unless wait = opts[:wait]
        raise DtkError::Client, "opts[:wait] must be set"
      end

      stage = 1
      task_end = false
      until task_end do
        elements = Stage.get(task_status_handle,stage)
        if no_results_yet?(elements)
          sleep wait
          next
        end
        
        render_elements(elements)
        
        if task_end?(elements)
          task_end = true
        else
          stage += 1
        end
      end
    end
    
    def render()
      #TODO: stub
      #TODO: make this nil and overwride all elements types to render
      pp [:element,self.class,self]
    end
    
    private
    
    def self.task_end?(elements)
      elements.empty? or elements.last.kind_of?(TaskEnd)
    end
    
    def self.no_results_yet?(elements)
      elements.find{|el|el.kind_of?(NoResults)}
    end
      
    def self.render_elements(elements)
      elements.each{|el|el.render()}
    end
    
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
    
  end
end; end
