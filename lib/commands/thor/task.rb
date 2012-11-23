module DTK::Client
  class Task < CommandBaseThor

    def self.whoami()
      return :task, "task/list", nil
    end

    desc "list [--list]","List tasks"
    method_option :list, :type => :boolean, :default => false
    def list()
      #TODO: just hard coded params now
      search_hash = SearchHash.new()
      search_hash.cols = [:commit_message,:status,:id,:created_at,:started_at,:ended_at]
      search_hash.filter = [:eq, ":task_id", nil] #just top level tasks
      search_hash.set_order_by!(:created_at,"DESC")
      response = post rest_url("task/list"), search_hash.post_body_hash()
      
      response.render_table(:task) unless options.list?
      return response
    end

    desc "[TASK-NAME/ID] status", "Return task status; if no TASK-ID then information about most recent task"
    method_option "detail-level",:default => "summary", :aliases => "-d", :desc => "detail level to report task status"
    def status(task_id=nil)
      detail_level = options["detail-level"]
      post_hash_body = Hash.new
      post_hash_body[:detail_level] = detail_level if detail_level
      post_hash_body[:task_id] = task_id if task_id
      post rest_url("task/status"),post_hash_body
    end

    desc "commit-changes", "Commit changes"
    def commit_changes(scope=nil)
      post_hash_body = Hash.new
      post_hash_body.merge!(:scope => scope) if scope
      post rest_url("task/create_task_from_pending_changes"),post_hash_body
    end

    desc "TASK-NAME/ID execute", "Execute task"
    def execute(task_id)
      post rest_url("task/execute"), :task_id => task_id
    end

    desc "commit-changes-and-execute", "Commit changes and execute task"
    def commit_changes_and_execute(scope=nil)
      response = commit_changes(scope)
      if response.ok?
        execute(response.data(:task_id))
      else
        response
      end
    end
    #alias for commit-changes-and-execute
    desc "simple-run", "Commit changes and execute task"
    def simple_run(scope=nil)
      commit_changes_and_execute(scope)
    end

    desc "converge-node NODE-ID", "(Re)Converge node"
    def converge_node(node_id=nil)
      scope = node_id && {:node_id => node_id} 
      response = post(rest_url("task/create_converge_state_changes"),scope)
      return response unless response.ok?
      response = commit_changes_and_execute(scope)
      while not task_complete(response) do
        response = status()
        sleep(TASK_STATUS_POLLING_INTERVAL)
      end
      response
    end

    desc "converge-nodes", "(Re)Converge nodes"
    def converge_nodes()
      converge_node(nil)
    end

  private
  
    @@count = 0

    TASK_STATUS_POLLING_INTERVAL = 3
    TASK_STATUS_MAX_TIME = 60

    def task_complete(response)
      return true unless response.ok?
      @@count += 1
      return true if (@@count * TASK_STATUS_POLLING_INTERVAL) > TASK_STATUS_MAX_TIME
      %w{succeeded failed}.include?(response.data(:status))
    end

  end
end

