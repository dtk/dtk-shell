module DTK::Client
  module PushCloneChangesMixin
    ##
    #
    # module_type: will be :component_module or :service_module 
    def push_clone_changes_aux(module_type,module_id,version,commit_msg=nil)
      id_field = "#{module_type}_id"
      post_body = {
        id_field => module_id
      }
      post_body.merge!(:version => version) if version 
      
      response =  post(rest_url("#{module_type}/get_workspace_branch_info"),post_body) 
      return response unless response.ok?
      module_name = response.data(:module_name)

      opts = {:commit_msg => commit_msg}
      response = Helper(:git_repo).push_changes(module_type,response.data(:module_name),version,opts)
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
