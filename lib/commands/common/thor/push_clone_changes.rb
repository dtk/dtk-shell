module DTK::Client
  module PushCloneChangesMixin
    ##
    #
    # module_type: will be :component_module or :service_module 
    def push_clone_changes_aux(module_type,module_id,version)
      id_field = "#{module_type}_id"
      post_body = {
        id_field => module_id
      }
      post_body.merge!(:version => version) if version 
      
      response =  post(rest_url("#{module_type}/get_workspace_branch_info"),post_body) 
      return response unless response.ok?
      module_name = response.data(:module_name)

      response = Helper(:git_repo).push_changes(module_type,response.data(:module_name),version)
      return response unless response.ok?
      json_diffs = (response.data(:diffs).empty? ? {} : JSON.generate(response.data(:diffs)))
      commit_sha = response.data(:commit_sha)
      repo_obj = response.data(:repo_obj)
      post_body.merge!(:json_diffs => JSON.generate(response.data(:diffs)), :commit_sha => commit_sha)

      response = post(rest_url("#{module_type}/update_model_from_clone"),post_body)
      return response unless response.ok?
      if module_type == :component_module
        dsl_created_info = response.data(:dsl_created_info)
        if dsl_created_info and !dsl_created_info.empty?
          msg = "First cut of dsl file (#{dsl_created_info["path"]}) has been created in the module directory; edit and then invoke 'dtk module #{module_name} push-clone-changes'"
          return Helper(:git_repo).add_file(repo_obj,dsl_created_info["path"],dsl_created_info["content"],msg)
        end
      end
      Rersponse::Ok.new(:json_diffs => json_diffs,:commit_sha => commit_sha)
    end
  end
end
