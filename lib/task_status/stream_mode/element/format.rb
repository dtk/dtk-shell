#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
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
        :duration_accuracy  => 1, # how many decimal places accuracy
        :include_start_time => true,
        :tab_size           => 2, # how many spaces each tab has
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

    def formatted_duration?(duration)
      if duration
        "#{duration.round(self[:duration_accuracy])}s"
      end
    end

    def duration_msg?(duration)
      if formatted_duration = formatted_duration?(duration)
        "DURATION: #{formatted_duration}"
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
      started_at = params[:started_at]
      if started_at and self[:include_start_time]
        msg_prefix << "#{started_at} "
      end
      ret = "#{msg_prefix}#{msg}"
      if  tabs = params[:tabs]
        ident = ' ' * (tabs * self[:tab_size])
        ret = ret.split("\n").map { |line| "#{ident}#{line}" }.join("\n") 
      end
      ret
    end
  end
end