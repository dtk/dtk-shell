module DTK::Client; class TaskStatus::StreamMode
  class Element
    module Render
      module Mixin
        def render_line(line)
          #TODO: stub
          STDOUT << line
          render_space
        end

        def render_space
          STDOUT << "\n"
        end
      end

      class Opts < ::Hash
        Defaults = {
          :task_start => {
            :include_time_stamp => true,
          },
          :stage => {
            :include_time_stamp => true,
          },
          :default => {
            :bracket_symbol     => '=',
            :bracket_num        => 25,
            :duration_accuracy  => 2,
            :include_time_stamp => true,
            :include_duration   => true,
          }
        }

        def initialize(type)
          @type = type && type.to_sym
          super()
          replace(Defaults[:default].merge(Defaults[@type] || {}))
        end

        def msg(msg, params = {})
          aug_msg = augment(msg, params)
          params[:bracket] ? bracket_msg(aug_msg) : aug_msg
        end

        private

        def bracket_msg(aug_msg)
          bracket_symbol = self[:bracket_symbol]
          bracket_num    = self[:bracket_num]
          "#{bracket_symbol * bracket_num} #{aug_msg} #{bracket_symbol * bracket_num}"
        end

        def augment(msg, params = {})
          msg_prefix = ''
          msg_posfix = ''
          add__started_at?(msg_prefix, params)
          add__duration?(msg_posfix, params)
          "#{msg_prefix}#{msg}#{msg_posfix}"
        end

        def add__started_at?(msg_prefix, params)
          started_at = params[:started_at]
          if started_at and self[:include_time_stamp]
            msg_prefix << "#{started_at} "
          end
        end

        def add__duration?(msg_posfix, params)
          duration = params[:duration]
          if duration and self[:include_duration]
            msg_posfix << " (duration: #{duration.round(self[:duration_accuracy])}s)"
          end
        end

      end
    end
  end
end; end
