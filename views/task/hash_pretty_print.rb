module DTK::Client::ViewMeta::Task
  HashPrettyPrint = {
    :top_type => :task,
    :defs => {
      :task_def =>
      [
       :type,
       :id,
       :status,
       :commit_message,
       {:node  => {:type => :node}},
       :started_at,
       :ended_at,
       :temporal_order,
       {:subtasks => {:type => :task, :is_array => true}},
       {:errors => {:type => :error, :is_array => true}} 
      ],
      :node_def => [:name, :id],
      :error_def => [:component, :message]
    }
  }
end

