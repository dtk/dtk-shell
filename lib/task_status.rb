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
module DTK::Client
  module TaskStatusMixin
    def task_status_aux(mode, object_id, object_type, opts = {})
      case mode
        when :refresh
          TaskStatus::RefreshMode.new(self, mode, object_id, object_type).task_status(opts)
        when :snapshot 
          TaskStatus::SnapshotMode.new(self, mode, object_id, object_type).task_status(opts)
        when :stream  
          assembly_or_workspace_id = object_id
          task_status_stream(assembly_or_workspace_id)
        else
          legal_modes = [:refresh, :snapshot, :stream]
          raise DtkError::Usage.new("Illegal mode '#{mode}'; legal modes are: #{legal_modes.join(', ')}")
      end
    end

    def task_status_stream(assembly_or_workspace_id, opts = {})
      TaskStatus::StreamMode.new(self, :stream, assembly_or_workspace_id, :assembly).get_and_render(opts)
    end

    def list_task_info_aux(object_type, object_id)
      response = TaskStatus.new(self, object_id, object_type).post_call(:form => :list)
      unless response.ok?
        DtkError.raise_error(response)
      end
      response.override_command_class("list_task")
      puts response.render_data
    end
  end

  dtk_require_common_commands('thor/base_command_helper')
  class TaskStatus < BaseCommandHelper
    require File.expand_path('task_status/snapshot_mode', File.dirname(__FILE__))
    require File.expand_path('task_status/refresh_mode', File.dirname(__FILE__))
    require File.expand_path('task_status/stream_mode', File.dirname(__FILE__))

    def initialize(command, mode, object_id, object_type)
      super(command)
      @mode        = mode
      @object_id   = object_id
      @object_type = object_type
    end

    private

    def post_body(opts = {})
      id_field = "#{@object_type}_id".to_sym
      PostBody.new(
        id_field                => @object_id,
        :form?                  => opts[:form],
        :wait_for?              => opts[:wait_for],
        :summarize_node_groups? => opts[:summarize]
     )
    end

    def post_call(opts={})
      response = post rest_url("#{@object_type}/task_status"), post_body(opts)
      unless response.ok?
        DtkError.raise_error(response)
      end
      response
    end

  end
end