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
      
      response = Helper(:git_repo).push_changes(module_type,response.data(:module_name),version)
      return response unless response.ok?
      json_diffs = (response.data(:diffs).empty? ? {} : JSON.generate(response.data(:diffs)))
      commit_sha = response.data(:commit_sha)
      post_body.merge!(:json_diffs => JSON.generate(response.data(:diffs)), :commit_sha => commit_sha)

      post rest_url("#{module_type}/update_model_from_clone"), post_body
    end
  end
end
