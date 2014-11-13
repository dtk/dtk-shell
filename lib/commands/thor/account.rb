dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_from_base('configurator')

module DTK::Client
  class Account < CommandBaseThor
    include ParseFile

    KEY_EXISTS_ALREADY_CONTENT = 'key exists already'

    no_tasks do

      def password_prompt(message, add_options=true)
        begin
          # while line = Readline.readline("#{message}: ", add_hist = false)
          # using 'ask' from highline gem to be able to hide input for key and secret
          while line = (HighLine.ask("#{message}") { |q| q.echo = false})
            raise Interrupt if line.empty?
            return line
          end
        rescue Interrupt
          return nil
        ensure
          puts "\n" if line.nil?
        end
      end
    end

    def self.internal_add_user_access(url, post_body, component_name)
      response = post(rest_url(url),post_body)
      key_exists_already = (response.error_message||'').include?(KEY_EXISTS_ALREADY_CONTENT)
      puts "Key exists already for #{component_name}" if key_exists_already
      [response, key_exists_already]
    end

    def self.add_key(path_to_key, name=nil)
      match, matched_username = nil, nil

      unless File.file?(path_to_key)
        # OsUtil.put_warning "[ERROR]  " ,"No ssh key file found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run `ssh-keygen -t rsa`)", :red
        raise DtkError,"[ERROR] No ssh key file found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run `ssh-keygen -t rsa`)."
      end

      rsa_pub_key = SSHUtil.read_and_validate_pub_key(path_to_key)

      post_body = { :rsa_pub_key => rsa_pub_key.chomp }
      post_body.merge!(:username => name.chomp) if name

      proper_response = nil
      response, key_exists_already = Account.internal_add_user_access("account/add_user_direct_access", post_body, 'service module')

      return response unless (response.ok? || key_exists_already)

      match = response.data['match']
      matched_username = response.data['matched_username']

      if response && !match
        repo_manager_fingerprint,repo_manager_dns = response.data_ret_and_remove!(:repo_manager_fingerprint,:repo_manager_dns)

        SSHUtil.update_ssh_known_hosts(repo_manager_dns,repo_manager_fingerprint)
        name ||= response.data["new_username"]
        OsUtil.print("SSH key '#{name}' added successfully!", :yellow)

      end

      return response, match, matched_username
    end

    desc "set-password", "Change password for your dtk user account"
    def set_password(context_params)
      old_pass_prompt, old_pass, new_pass_prompt, confirm_pass_prompt = nil
      cred_file = ::DTK::Client::Configurator::CRED_FILE
      old_pass = parse_key_value_file(cred_file)[:password]
      username = parse_key_value_file(cred_file)[:username]

      if old_pass.nil?
        OsUtil.print("Unable to retrieve your current password!", :yellow)
        return
      end

      3.times do
        old_pass_prompt = password_prompt("Enter old password: ")

        break if (old_pass.eql?(old_pass_prompt) || old_pass_prompt.nil?)
        OsUtil.print("Incorrect old password!", :yellow)
      end
      return unless old_pass.eql?(old_pass_prompt)

      new_pass_prompt = password_prompt("Enter new password: ")
      return if new_pass_prompt.nil?
      confirm_pass_prompt = password_prompt("Confirm new password: ")

      if new_pass_prompt.eql?(confirm_pass_prompt)
        post_body = {:new_password => new_pass_prompt}
        response = post rest_url("account/set_password"), post_body
        return response unless response.ok?

        ::DTK::Client::Configurator.regenerate_conf_file(cred_file, [['username', "#{username.to_s}"], ['password', "#{new_pass_prompt.to_s}"]], '')
        OsUtil.print("Password changed successfully!", :yellow)
      else
        OsUtil.print("Entered passwords don't match!", :yellow)
        return
      end
    end

    desc "list-ssh-keys", "Show list of key pairs that your account profile has saved"
    def list_ssh_keys(context_params)
      username  = parse_key_value_file(::DTK::Client::Configurator::CRED_FILE)[:username]
      post_body = {:username => username}

      response = post rest_url("account/list_ssh_keys"), post_body
      response.render_table(:account_ssh_keys)
    end

    desc "add-ssh-key KEYPAIR-NAME [PATH-TO-RSA-PUB-KEY]","Adds a named ssh key to your user account to access modules from the catalog. Optional parameters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def add_ssh_key(context_params)
      name, path_to_key = context_params.retrieve_arguments([:option_1!, :option_2],method_argument_names)
      path_to_key ||= SSHUtil.default_rsa_pub_key_path()

      response, matched, matched_username = Account.add_key(path_to_key, name)

      if matched
        DTK::Client::OsUtil.print("Provided ssh pub key has already been added.", :yellow)
      elsif matched_username
        DTK::Client::OsUtil.print("User ('#{matched_username}') already exists.", :yellow)
      else
        DTK::Client::Configurator.add_current_user_to_direct_access() if response.ok?
      end

      if response.ok? && !response.data(:registered_with_repoman)
        OsUtil.print("Warning: We were not able to register your key with remote catalog!", :yellow)
      end

      response.ok? ? nil : response
    end

    desc "delete-ssh-key KEYPAIR-NAME [-y]","Deletes the named ssh key from your user account"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_ssh_key(context_params)
      name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      unless options.force?
        is_go = Console.confirmation_prompt("Are you sure you want to delete SSH key '#{name}'"+"?")
        return nil unless is_go
      end

      response = post rest_url("account/remove_user_direct_access"), { :username => name.chomp }
      return response unless response.ok?

      if response.ok? && !response.data(:unregistered_with_repoman)
        OsUtil.print("Warning: We were not able to unregister your key with remote catalog!", :yellow)
      end

      OsUtil.print("SSH key '#{name}' removed successfully!", :yellow)
      nil
    end

    desc "set-default-namespace NAMESPACE", "Sets default namespace for your user account"
    def set_default_namespace(context_params)
      default_namespace = context_params.retrieve_arguments([:option_1!],method_argument_names)
      post_body = { :namespace => default_namespace.chomp }

      response = post rest_url("account/set_default_namespace"), post_body
      return response unless response.ok?

      OsUtil.print("Your default namespace has been set to '#{default_namespace}'!", :yellow)
      nil
    end

    desc "set-catalog-credentials", "Sets catalog credentials"
    def set_catalog_credentials(context_params)
      creds = DTK::Client::Configurator.enter_catalog_credentials()

      response = post rest_url("account/set_catalog_credentials"), { :username => creds[:username], :password => creds[:password] }
      return response unless response.ok?

      OsUtil.print("Your catalog credentials have been set!", :yellow)
      nil
    end



    # Will leave this commented for now until we check if above commands work as expected
    #
    # def self.add_access(path_to_key)
    #   unless File.file?(path_to_key)
    #     raise DTK::Client::DtkError,"No ssh key file found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
    #   end
    #   rsa_pub_key = File.open(path_to_key){|f|f.read}
    #   post_body = {
    #     :rsa_pub_key => rsa_pub_key.chomp
    #   }

    #   proper_response = nil

    #   response, key_exists_already = Account.internal_add_user_access("service_module/add_user_direct_access", post_body, 'service module')
    #   return response unless (response.ok? || key_exists_already)
    #   proper_response = response if response.ok?

    #   response, key_exists_already = Account.internal_add_user_access("component_module/add_user_direct_access", post_body, 'component module')
    #   return response unless (response.ok? || key_exists_already)
    #   proper_response = response if response.ok?

    #   # if either of request passed we will add to known hosts
    #   if proper_response
    #     repo_manager_fingerprint,repo_manager_dns = proper_response.data_ret_and_remove!(:repo_manager_fingerprint,:repo_manager_dns)
    #     SSHUtil.update_ssh_known_hosts(repo_manager_dns,repo_manager_fingerprint)
    #     return proper_response
    #   else
    #     nil
    #   end
    # end

    # desc "add-direct-access [PATH-TO-RSA-PUB-KEY]","Adds direct access to modules. Optional parameters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    # def add_direct_access(context_params)
    #   return
    #   path_to_key = context_params.retrieve_arguments([:option_1],method_argument_names)
    #   path_to_key ||= SSHUtil.default_rsa_pub_key_path()
    #   access_granted = Account.add_access(path_to_key)

    #   FileUtils.touch(DTK::Client::Configurator::DIRECT_ACCESS) if access_granted
    #   access_granted
    # end

    # desc "remove-direct-access [PATH-TO-RSA-PUB-KEY]","Removes direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    # def remove_direct_access(context_params)
    #   path_to_key = context_params.retrieve_arguments([:option_1],method_argument_names)
    #   path_to_key ||= SSHUtil.default_rsa_pub_key_path()

    #   # path_to_key ||= "#{ENV['HOME']}/.ssh/id_rsa.pub" #TODO: very brittle
    #   unless File.file?(path_to_key)
    #     raise DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
    #   end
    #   rsa_pub_key = File.open(path_to_key){|f|f.read}
    #   post_body = {
    #     :rsa_pub_key => rsa_pub_key.chomp
    #   }
    #   response = post rest_url("component_module/remove_user_direct_access"), post_body
    #   return response unless response.ok?

    #   response = post rest_url("service_module/remove_user_direct_access"), post_body
    #   return response unless response.ok?

    #   FileUtils.rm(DTK::Client::Configurator::DIRECT_ACCESS) if File.exists?(DTK::Client::Configurator::DIRECT_ACCESS)
    #   return response
    # end

  end
end