module DTK::Client; class TaskStatus::StreamMode
  class Element
    module Render
      module Mixin
        def render_line(line)
          #TODO: stub
          STDOUT << line << "\n"
        end
      end

      class Opts < ::Hash
        Defaults = {
          :task_start => {
            :bracket_symbol     => '=',
            :bracket_num        => 25,
            :include_time_stamp => true,
          },
          :default => {
            :bracket_symbol     => '=',
            :bracket_num        => 25,
            :include_time_stamp => true,
          }
        }

        def initialize(type)
          @type = type && type.to_sym
          super()
          replace(Defaults[@type] || Defaults[:default])
        end

        def bracketed_msg(msg, params = {})
          bracket_symbol = self[:bracket_symbol]
          bracket_num    = self[:bracket_num]
          "#{bracket_symbol * bracket_num} #{augment(msg, params)} #{bracket_symbol * bracket_num}"
        end
        
        private

        def augment(msg, params = {})
          started_at = params[:started_at]
          if started_at and self[:include_time_stamp]
            "#{started_at} #{msg}"
          else
            msg
          end

        end
      end
    end
  end
end; end
