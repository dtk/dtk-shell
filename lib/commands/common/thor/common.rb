module DTK::Client
  module CommonMixin
   private
    #returns module_name,repo_url,branch,not_ok_response( only if error)
    def workspace_branch_info(module_type,module_id,version,opts={})
      if info = opts[:workspace_branch_info]
        [info[:module_name],info[:repo_url],info[:branch]]
      else
        post_body = get_workspace_branch_info_post_body(module_type,module_id,version,opts)
        response = post(rest_url("#{module_type}/get_workspace_branch_info"),post_body)
        unless response.ok?
          [nil,nil,nil,response]
        else
          response.data(:module_name,:repo_url,:workspace_branch)
        end
      end
    end

    def get_workspace_branch_info_post_body(module_type,module_id,version_explicit,opts={})
      id_field = "#{module_type}_id"
      post_body = {
        id_field => module_id
      }
      assembly_module = opts[:assembly_module]
      if version = version_explicit||(assembly_module && assembly_module[:version])
        post_body.merge!(:version => version) 
      end
      if assembly_module
        post_body.merge!(:assembly_module => true,:assembly_name => assembly_module[:assembly_name])
      end
      post_body
    end
  end
end
