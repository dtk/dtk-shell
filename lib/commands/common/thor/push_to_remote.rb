dtk_require_common_commands('thor/common')
module DTK::Client
  module PushToRemoteMixin

    def push_to_git_remote_aux(full_module_name, module_type, version, opts, force = false)
      opts.merge!(:force => force)

      response = Helper(:git_repo).push_changes(module_type, full_module_name, version, opts)

      return response unless response.ok?
      if response.data(:diffs).empty?
        raise DtkError, "No changes to push"
      end

      Response::Ok.new()
    end

    def push_to_git_remote_location_aux(full_module_name, module_type, version, opts, force = false)
      opts.merge!(:force => force)

      # staging dir which will be removed
      temp_stage_dir = OsUtil.temp_git_remote_location()
      content_dir    = File::join(temp_stage_dir, opts[:remote_repo_location])

      begin
        # clone desired repo
        GitAdapter.clone(opts[:remote_repo_url], temp_stage_dir, opts[:remote_branch])
        # make sure that content dir exist
        FileUtils.mkdir_p(content_dir)
        # copy content of module to new dir (overriding everything in process)
        module_location = OsUtil.module_location(module_type, full_module_name, version)
        FileUtils.cp_r(File.join(module_location, '/.'), content_dir)
        # remove git folder
        FileUtils.rm_rf(File.join(content_dir, '.git'))
        # now we push it
        opts.merge!(:override_repo_dir_location => temp_stage_dir)
        response = Helper(:git_repo).push_changes(module_type, full_module_name, version, opts)
        return response unless response.ok?

        if response.data(:diffs).empty?
          raise DtkError, "No changes to push"
        end

        Response::Ok.new()
      ensure
        FileUtils.rm_rf(temp_stage_dir)
      end
    end

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
