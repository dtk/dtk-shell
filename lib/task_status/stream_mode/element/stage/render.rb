class DTK::Client::TaskStatus::StreamMode::Element::Stage
  module Render
    module Mixin
      def render
        render_start unless @just_render and @just_render != :start
        render_end unless @just_render and @just_render != :end
      end
      
      private
      
      def render_start
        if @ignore_stage_level_info
          render_stage_steps field?(:subtasks)
          render_start_time field?(:started_at)
        else
          render_border
          render_line line__stage_heading?
          render_start_time field?(:started_at)
          render_stage_steps field?(:subtasks)
        end
      end
      
      def render_end
        render_line line__status
        render_duration_line
        render_stage_results field?(:subtasks)
        unless @ignore_stage_level_info
          render_border
          render_empty_line
        end
      end
      
      def line__stage_heading?
        stage_num  = field?(:position)
        stage_name = stage_name?
        
        unless stage_num.nil? and stage_name.nil?
          msg = 'STAGE'
          if stage_num  = field?(:position)
            msg << " #{stage_num.to_s}"
          end
          
          if stage_name = stage_name?
            msg << ": #{stage_name}"
          end
          msg
        end
      end
      
      def line__status
        "STATUS: #{field?(:status) || 'UNKNOWN'}"
      end
      
      def stage_name?
        field?(:display_name)
      end
    end
  end
end
