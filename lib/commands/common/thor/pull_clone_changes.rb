dtk_require_common_commands('thor/common')
module DTK::Client
  module PullCloneChangesMixin
    def pull_clone_changes?(module_type,module_id,version=nil,opts={})
      module_name, module_namespace,repo_url,branch,not_ok_response = workspace_branch_info(module_type,module_id,version,opts)
      full_module_name = ModuleUtil.resolve_name(module_name, module_namespace)
      return not_ok_response if not_ok_response
      Helper(:git_repo).pull_changes(module_type,full_module_name,opts.merge(:local_branch => branch))
    end
  end
end

