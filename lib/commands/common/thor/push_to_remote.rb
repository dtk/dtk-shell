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
      #TODO: stub
      return response
      return response unless response.ok?
    end

  end
end
