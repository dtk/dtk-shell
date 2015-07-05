module DTK::Client
  module TaskStatusMixin
    def task_status_aux(mode, object_id, object_type, opts={})
      case mode
        when :refresh
          TaskStatus::RefreshMode.new(self,mode,object_id,object_type).task_status(opts)
        when :snapshot 
          TaskStatus::SnapshotMode.new(self,mode,object_id,object_type).task_status(opts)
        when :stream  
          task_status_stream(assembly_or_workspace_id)
        else
          raise DtkError, "[ERROR] illegal mode '#{mode}'"
      end
    end

    def task_status_stream(assembly_or_workspace_id)
      TaskStatus::StreamMode.new(self,:stream,assembly_or_workspace_id,:assembly).task_status()
    end

    def list_task_info_aux(object_type, object_id)
      response = TaskStatus.new(self,object_id,object_type).post_call(:form => :list)
      raise DtkError, "[SERVER ERROR] #{response['errors'].first['message']}." if response["status"].eql?('notok')
      response.override_command_class("list_task")
      puts response.render_data
    end
  end

  dtk_require_common_commands('thor/base_command_helper')
  class TaskStatus < BaseCommandHelper
    dtk_require_common_commands('thor/task_status/snapshot_mode')
    dtk_require_common_commands('thor/task_status/refresh_mode')
    dtk_require_common_commands('thor/task_status/stream_mode')

    def initialize(command,mode,object_id,object_type)
      super(command)
      @mode        = mode
      @object_id   = object_id
      @object_type = object_type
    end


    private

    def post_body(opts={})
      id_field = "#{@object_type}_id".to_sym
      PostBody.new(
        id_field                => @object_id,
        :form?                  => opts[:form],
        :summarize_node_groups? => opts[:summarize]
     )
    end
    def post_call(opts={})
      response = post rest_url("#{@object_type}/task_status"), post_body(opts)
      unless response.ok?
        raise DtkError, "[SERVER ERROR] #{response['errors'].first['message']}." 
      end
      response
    end

  end
end
