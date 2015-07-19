require 'hirb'
module DTK::Client
  class TaskStatus
    class StreamMode < self
      require File.expand_path('stream_mode/element', File.dirname(__FILE__))

      def get_and_render()
        Element.get_and_render_task_start(self)
        Element.get_and_render_stages(self,:wait => WaitWhenNoResults)
        Response::Ok.new()
      end

      WaitWhenNoResults = 5 #in seconds
      # making this public for this class and its children
      def post_call(*args)
        super
      end

      private
      
      # This uses a cursor based interface to the server
      #    start_index: START_INDEX
      #    end_index: END_INDEX
      # convention is start_position = 0 and end_position = 0 means top level task with start time 
      def post_body(opts={})
        ret = super(opts)
        ret.merge(:start_index => opts[:start_index], :end_index => opts[:end_index])
      end
    end
  end
end
