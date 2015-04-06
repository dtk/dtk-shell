dtk_require_common_commands('thor/common')
module DTK::Client
  module PushToRemoteMixin

    def push_to_remote_aux(remote_module_info, module_type, force = false)
      full_module_name     = remote_module_info.data(:full_module_name)
      version = remote_module_info.data(:version)

      opts = {
        :remote_repo_url => remote_module_info.data(:remote_repo_url),
        :remote_repo => remote_module_info.data(:remote_repo),
        :remote_branch => remote_module_info.data(:remote_branch),
        :local_branch => remote_module_info.data(:workspace_branch),
        :where => 'catalog',
        :force => force
      }
      response = Helper(:git_repo).push_changes(module_type, full_module_name, version, opts)
      return response unless response.ok?
      if response.data(:diffs).empty?
        raise DtkError, "No changes to push"
      end

      Response::Ok.new()
    end

  end
end
