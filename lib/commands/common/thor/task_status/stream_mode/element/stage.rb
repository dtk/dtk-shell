module DTK::Client; class TaskStatus::StreamMode
  class Element
    class Stage < self
      require File.expand_path('stage/render', File.dirname(__FILE__))
      include Render::Mixin

      def initialize(response_element, opts = {})
        super(response_element)
        @just_render = opts[:just_render]
      end
      
      # opts has
      #   :wait - amount to wait if get no results (required)
      def self.get_and_render_stages(task_status_handle, opts = {})
        unless wait = opts[:wait]
          raise DtkError::Client, "opts[:wait] must be set"
        end
        
        cursor = Cursor.new
        until cursor.task_end? do
          elements = get_single_stage(task_status_handle, cursor.stage, :wait_for => cursor.wait_for)
          if no_results_yet?(elements)
            sleep wait
            next
          end
          render_elements(elements)
          cursor.advance!(task_end?(elements))
        end
      end
    
      class Cursor
        def initialize
          @stage    = 1
          @wait_for = :start
          @task_end = false
        end
        attr_reader :stage, :wait_for
        def task_end?
          @task_end
        end
        def advance!(task_end)
          unless @task_end = task_end
            if @wait_for == :start
              @wait_for = :end
            else
              @stage += 1
              @wait_for = :start
            end
          end
        end
      end
      
      def self.get_single_stage(task_status_handle, stage_num, opts = {})
        get_stages(task_status_handle, stage_num, stage_num, opts)
      end
      
      def self.get_stages(task_status_handle, start_stage_num, end_stage_num, opts = {})
        opts_get = {
          :start_index => start_stage_num, 
          :end_index   => end_stage_num
        }.merge(opts)
        get_task_status_elements(task_status_handle, :stage, opts_get)
      end
      
    end
  end
end; end
