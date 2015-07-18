class DTK::Client::TaskStatus::StreamMode::Element
  class Format < ::Hash
    Settings = {
      :task_start => {
      },
      :task_end => {
      },
      :stage => {
      },
      :stage_start => {
        :border_symbol      => '=',
      },
      :stage_end => {
        :border_symbol      => '-',
      },
      :default => {
        :border_symbol      => '=',
        :border_size        => 60,
        :bracket_symbol     => '=',
        :bracket_size       => 25,
        :duration_accuracy  => 2, # how many decimal places accuracy
        :include_start_time => true
      }
    }
    
    def initialize(type)
      super()
      @type = type && type.to_sym
      replace(Settings[:default].merge(Settings[@type] || {}))
    end
      
    def format(msg, params = {})
      aug_msg = augment(msg, params)
      params[:bracket] ? bracket(aug_msg) : aug_msg
    end
    
    def border
      border_symbol = self[:border_symbol]
      border_size    = self[:border_size]
      "#{border_symbol * border_size}"
    end
    
    def start_time_msg?(started_at)
      if started_at
        "TIME START: #{started_at}"
      end
    end
    
    def duration_msg?(duration)
      if duration
        "DURATION: #{duration.round(self[:duration_accuracy])}s"
      end
    end

    private
    
    def bracket(aug_msg)
      bracket_symbol = self[:bracket_symbol]
      bracket_size    = self[:bracket_size]
      "#{bracket_symbol * bracket_size} #{aug_msg} #{bracket_symbol * bracket_size}"
    end
    
    def augment(msg, params = {})
      msg_prefix = ''
      msg_posfix = ''
      
      started_at = params[:started_at]
      if started_at and self[:include_start_time]
        msg_prefix << "#{started_at} "
      end
      
      "#{msg_prefix}#{msg}#{msg_posfix}"
    end
  end
end


