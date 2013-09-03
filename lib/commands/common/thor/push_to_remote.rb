module DTK::Client
  module PushToRemoteMixin

    ##
    #
    # module_type: will be :component_module or :service_module

    def push_to_remote_aux(module_type,module_id, module_name,remote_namespace,version=nil)       
      id_field = "#{module_type}_id"
      path_to_key = SshProcessing.default_rsa_pub_key_path()
      unless File.file?(path_to_key)
        raise DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        id_field => module_id,
        :rsa_pub_key => rsa_pub_key.chomp,
        :access_rights => "rw",
        :action => "push"
      }
      post_body.merge!(:version => version) if version
      post_body.merge!(:remote_namespace => remote_namespace) if remote_namespace
      response = post(rest_url("#{module_type}/get_remote_module_info"),post_body)

      return response unless response.ok?

      returned_module_name = response.data(:module_name)
      opts = {
        :remote_repo_url => response.data(:remote_repo_url),
        :remote_repo => response.data(:remote_repo),
        :remote_branch => response.data(:remote_branch),
        :local_branch => response.data(:workspace_branch)
      }

      version = response.data(:version)

      response = Helper(:git_repo).push_changes(module_type,returned_module_name,version,opts)
      return response unless response.ok?
      if response.data(:diffs).empty?
        raise DtkError, "No changes to push"
      end
      
      Response::Ok.new()
    end

  end
end
