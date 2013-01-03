module DTK::Client
  module PushToRemoteMixin

    ##
    #
    # module_type: will be :component_module or :service_module

    def push_to_remote_aux(module_type,module_id)
      id_field = "#{module_type}_id"
      path_to_key = SshProcessing.default_rsa_pub_key_path()
      unless File.file?(path_to_key)
        raise DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        id_field => module_id,
        :rsa_pub_key => rsa_pub_key.chomp
      }
      response = post(rest_url("#{module_type}/check_remote_auth"),post_body)

      dtk_require_from_base('command_helpers/git_repo')
      module_name = response.data(:module_name)
      opts = {
        :remote_url => response.data(:remote_url),
        :remote_repo => response.data(:remote_repo),
        :remote_branch => response.data(:remote_branch)
      }
      response = GitRepo.push_changes(module_type,module_name,opts)
      return response unless response.ok?
      if response.data(:diffs).empty?
        raise DtkError, "No changes to push"
      end
      response
    end

  end
end
