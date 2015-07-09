require 'hirb'
module DTK::Client
  class TaskStatus
    class StreamMode < self
      require File.expand_path('stream_mode/element',File.dirname(__FILE__))

      # This uses a cursor based interface to the server
      #  get_task_status
      #    start_position: START_INDEX
      #    end_position: END_INDEX
      # convention is start_position = 0 and end_position =0 means top level task with start time 
      def task_status()
        # first get task start
        task_elements = Element.get_task_start(self)
        Element.render_elements(task_elements)
        stage = 1
        task_end = false
        until task_end do
          task_elements = Element.get_stage(self,stage)
          Element.render_elements(task_elements)
          if task_elements.last.task_end?()
            task_end = true
          else
            stage += 1
          end
        end
        Response::Ok.new
      end

      # making this public for this class and its children
      def post_call(*args)
        super
      end

     private
      def post_body(opts={})
        ret = super(opts)
        ret.merge(:start_index => opts[:start_index], :end_index => opts[:end_index])
      end
    end
  end
end
