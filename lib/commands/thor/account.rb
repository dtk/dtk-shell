dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/push_to_remote')
dtk_require_common_commands('thor/pull_from_remote')
dtk_require_common_commands('thor/push_clone_changes')
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_common_commands('thor/task_status')
dtk_require_common_commands('thor/set_required_params')

module DTK::Client
  class Account < CommandBaseThor

    no_tasks do
      include CloneMixin
      include PushToRemoteMixin
      include PullFromRemoteMixin
      include PushCloneChangesMixin
    end

  

  	desc "add-direct-access [PATH-TO-RSA-PUB-KEY]","Adds direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
	  def add_direct_access(context_params)
	    path_to_key = context_params.retrieve_arguments([:option_1],method_argument_names)
	    path_to_key ||= SshProcessing.default_rsa_pub_key_path()
	    unless File.file?(path_to_key)
	      raise DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
	    end
	    rsa_pub_key = File.open(path_to_key){|f|f.read}
	    post_body = {
	      :rsa_pub_key => rsa_pub_key.chomp
	    }
	    
	    response = post(rest_url("service_module/add_user_direct_access"),post_body)
      puts response["errors"].first["message"] + ' for service module.' unless response.ok?

      response = post(rest_url("component_module/add_user_direct_access"),post_body)
      puts response["errors"].first["message"]+ ' for component module.' unless response.ok?

      if response.ok?
      	repo_manager_fingerprint,repo_manager_dns = response.data_ret_and_remove!(:repo_manager_fingerprint,:repo_manager_dns)
      	SshProcessing.update_ssh_known_hosts(repo_manager_dns,repo_manager_fingerprint)
      	return response
      end
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