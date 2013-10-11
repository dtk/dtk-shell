dtk_require_common_commands('thor/common')
module DTK::Client
  module PullCloneChangesMixin
    def pull_clone_changes?(module_type,module_id,version=nil,opts={})
      module_name,repo_url,branch,not_ok_response = workspace_branch_info(module_type,module_id,version,opts)
      return not_ok_response if not_ok_response
      Helper(:git_repo).pull_changes(module_type,module_name,opts.merge(:local_branch => branch))
    end
  end
end

