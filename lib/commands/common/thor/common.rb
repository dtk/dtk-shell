module DTK::Client
  module CommonMixin
   private
    # returns module_name, module_namespace, repo_url, branch, not_ok_response( only if error)
    def workspace_branch_info(module_type, module_id, version, opts={})
      # shortcut if have info about workspace branch already
      if info = opts[:workspace_branch_info]
        name_or_full_module_name = info[:module_name]
        module_namespace, module_name = ModuleUtil.full_module_name_parts?(name_or_full_module_name)
        module_namespace ||= info[:module_namespace]
        ret = [module_name, module_namespace, info[:repo_url], info[:branch]]
        unless  ret.find{|r|r.nil?}
          return ret
        end
      end

      # if 'base' returned as version set to nil; 'base' = 'master' = nil
      version = nil if version == 'base'

      post_body = get_workspace_branch_info_post_body(module_type, module_id, version, opts)
      response = post(rest_url("#{module_type}/get_workspace_branch_info"),post_body)
      unless response.ok?
        ret = [nil, nil, nil, nil, response, nil]
      else
        m_name, m_namespace, repo_url, w_branch, version = response.data(:module_name, :module_namespace, :repo_url, :workspace_branch, :version)
        ret = [m_name, m_namespace, repo_url, w_branch, nil]
        ret << version if opts[:use_latest]
      end
      ret
    end

    def get_workspace_branch_info_post_body(module_type, module_id, version_explicit, opts={})
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
      if use_latest = opts[:use_latest]
        post_body.merge!(:use_latest => use_latest)
      end
      post_body
    end

    def get_remote_module_info_aux(module_type, module_id, remote_namespace, version=nil, module_refs_content=nil, local_namespace=nil)
      id_field      = "#{module_type}_id"
      rsa_pub_value = SSHUtil.rsa_pub_key_content()

      post_body = {
        id_field => module_id,
        :rsa_pub_key => rsa_pub_value,
        :access_rights => "rw",
        :action => "push"
      }
      post_body.merge!(:version => version) if version
      post_body.merge!(:remote_namespace => remote_namespace) if remote_namespace
      post_body.merge!(:local_namespace => local_namespace) if local_namespace
      post_body.merge!(:module_ref_content => module_refs_content) if module_refs_content && !module_refs_content.empty?

      response = post(rest_url("#{module_type}/get_remote_module_info"),post_body)
      RemoteDependencyUtil.print_dependency_warnings(response)
      response
    end

  end
end
