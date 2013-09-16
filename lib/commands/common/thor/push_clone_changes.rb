dtk_require_common_commands('thor/common')
module DTK::Client
  module PushCloneChangesMixin
    include CommonMixin
    ##
    #
    # module_type: will be :component_module or :service_module 
    def push_clone_changes_aux(module_type,module_id,version,commit_msg,internal_trigger=false,opts={})
      module_name,repo_url,branch,not_ok_response = workspace_branch_info(module_type,module_id,version,opts)
      return not_ok_response if not_ok_response

      push_opts = opts.merge(:commit_msg => commit_msg, :local_branch => branch)
      response = Helper(:git_repo).push_changes(module_type,module_name,version,push_opts)
      return response unless response.ok?

      json_diffs = (response.data(:diffs).empty? ? {} : JSON.generate(response.data(:diffs)))
      commit_sha = response.data(:commit_sha)
      repo_obj = response.data(:repo_obj)
      post_body.merge!(:json_diffs => JSON.generate(response.data(:diffs)), :commit_sha => commit_sha)

      response = post(rest_url("#{module_type}/update_model_from_clone"),post_body)
      return response unless response.ok?
      
      if (!response.data.empty? && response.data(:dsl_parsed_info))
        dsl_parsed_message = "Module '#{module_name}' imported with errors:\n#{response.data(:dsl_parsed_info)}\nYou can fix errors and import module again.\n"
        DTK::Client::OsUtil.print(dsl_parsed_message, :red) 
      end
      
      if module_type == :component_module
        dsl_created_info = response.data(:dsl_created_info)
        if dsl_created_info and !dsl_created_info.empty?
          msg = "A #{dsl_created_info["path"]} file has been created for you, located at #{repo_obj.repo_dir}"
          return Helper(:git_repo).add_file(repo_obj,dsl_created_info["path"],dsl_created_info["content"],msg)
        end
      end
      Response::Ok.new(:json_diffs => json_diffs,:commit_sha => commit_sha)
    end
  end
end
