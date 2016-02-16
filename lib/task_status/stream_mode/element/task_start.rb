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
module DTK::Client; class TaskStatus::StreamMode
  class Element
    class TaskStart < self
      def self.get(task_status_handle, opts = {})
        opts_get = {
          :start_index => 0,
          :end_index   => 0
        }.merge(opts)
        get_task_status_elements(task_status_handle, :task_start, opts_get)
      end

      def render
        return if @ignore_stage_level_info
        msg = "start '#{field?(:display_name) || 'Workflow'}'"
        render_line msg, :bracket => true, :started_at => field?(:started_at)
        render_empty_lines 2
      end
    end
  end
end; end
