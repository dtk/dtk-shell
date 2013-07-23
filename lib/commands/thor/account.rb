dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")

module DTK::Client
  class Account < CommandBaseThor

    KEY_EXISTS_ALREADY_CONTENT = 'key exists already'

    def self.internal_add_user_access(url, post_body, component_name)
      response = post(rest_url(url),post_body)
      key_exists_already = (response.error_message||'').include?(KEY_EXISTS_ALREADY_CONTENT)
      puts "Key exists already for #{component_name}" if key_exists_already
      [response, key_exists_already]
    end
    # end

    def self.add_access(path_to_key)
      unless File.file?(path_to_key)
        raise DTK::Client::DtkError,"No ssh key file found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        :rsa_pub_key => rsa_pub_key.chomp
      }

      proper_response = nil

      response, key_exists_already = Account.internal_add_user_access("service_module/add_user_direct_access", post_body, 'service module')
      return response unless (response.ok? || key_exists_already)
      proper_response = response if response.ok?

      response, key_exists_already = Account.internal_add_user_access("component_module/add_user_direct_access", post_body, 'component module')
      return response unless (response.ok? || key_exists_already)
      proper_response = response if response.ok?
      
      # if either of request passed we will add to known hosts
      if proper_response
        repo_manager_fingerprint,repo_manager_dns = proper_response.data_ret_and_remove!(:repo_manager_fingerprint,:repo_manager_dns)
        SshProcessing.update_ssh_known_hosts(repo_manager_dns,repo_manager_fingerprint)
        return proper_response
      else
        nil
      end
    end

  	desc "add-direct-access [PATH-TO-RSA-PUB-KEY]","Adds direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
	  def add_direct_access(context_params)
	    path_to_key = context_params.retrieve_arguments([:option_1],method_argument_names)
	    path_to_key ||= SshProcessing.default_rsa_pub_key_path()
      Account.add_access(path_to_key)
	    # unless File.file?(path_to_key)
	    #   raise DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
	    # end
	    # rsa_pub_key = File.open(path_to_key){|f|f.read}
	    # post_body = {
	    #   :rsa_pub_key => rsa_pub_key.chomp
	    # }

     #  proper_response = nil

     #  response, key_exists_already = internal_add_user_access("service_module/add_user_direct_access", post_body, 'service module')
     #  return response unless (response.ok? || key_exists_already)
     #  proper_response = response if response.ok?

     #  response, key_exists_already = internal_add_user_access("component_module/add_user_direct_access", post_body, 'component module')
     #  return response unless (response.ok? || key_exists_already)
     #  proper_response = response if response.ok?
      
     #  # if either of request passed we will add to known hosts
     #  if proper_response
     #  	repo_manager_fingerprint,repo_manager_dns = proper_response.data_ret_and_remove!(:repo_manager_fingerprint,:repo_manager_dns)
     #  	SshProcessing.update_ssh_known_hosts(repo_manager_dns,repo_manager_fingerprint)
     #  	return proper_response
     #  else
     #    nil
     #  end
	  end

	  desc "remove-direct-access [PATH-TO-RSA-PUB-KEY]","Removes direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def remove_direct_access(context_params)
      path_to_key = context_params.retrieve_arguments([:option_1],method_argument_names)
	    path_to_key ||= SshProcessing.default_rsa_pub_key_path()

      # path_to_key ||= "#{ENV['HOME']}/.ssh/id_rsa.pub" #TODO: very brittle
      unless File.file?(path_to_key)
        raise DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        :rsa_pub_key => rsa_pub_key.chomp
      }
      response = post rest_url("component_module/remove_user_direct_access"), post_body
      return response unless response.ok?

      response = post rest_url("service_module/remove_user_direct_access"), post_body
      return response unless response.ok?

      return response
    end

	end
end