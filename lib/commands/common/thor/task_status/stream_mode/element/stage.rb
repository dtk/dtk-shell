module DTK::Client; class TaskStatus::StreamMode
  class Element
    class Stage < self
      def self.get(task_status_handle,stage_num)
        get_stages(task_status_handle,stage_num,stage_num+1)
      end
      def self.get_stages(task_status_handle,start_stage_num,end_stage_num)
        get_task_status_elements(task_status_handle,:stage,:start_index => start_stage_num, :end_index => end_stage_num)
      end
    end
  end
end; end
