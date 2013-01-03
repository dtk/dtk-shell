#TODO: may be consistent on whether service module id or service module name used as params
dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_from_base('command_helpers/git_repo')
dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/push_clone_changes')
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_common_commands('thor/task_status')
dtk_require_common_commands('thor/set_required_params')

module DTK::Client
  class Service < CommandBaseThor

    no_tasks do
      include CloneMixin
      include PushCloneChangesMixin
    end

    def self.pretty_print_cols()
      PPColumns.get(:service_module)
    end

    def self.whoami()
      return :service_module, "service_module/list", nil
    end
    
    desc "SERVICE-NAME/ID info", "Provides information about specified service module"
    def info(service_module_id)
      post_body = {
       :service_module_id => service_module_id
      }
      response = post rest_url('service_module/info')
    end

    desc "[SERVICE-NAME/ID] list [assemblies] [--remote]","List local or remote service modules or assemblies associated to it."
    method_option :list, :type => :boolean, :default => false
    method_option :remote, :type => :boolean, :default => false
    def list(about="none",service_module_id=nil)
      post_body = {
       :service_module_id => service_module_id,
      }

      case about
       when "none":
         action = (options.remote? ? "list_remote" : "list")
         response = post rest_url("service_module/#{action}")
         data_type = :module
       when "assemblies":
         if options.remote?
           #TODO: this is temp; will shortly support this
           raise DTK::Client::DtkError, "Not supported '--remote' option when listing service module assemblies"
         end
         response = post rest_url("service_module/list_assemblies"),post_body
         data_type = :assembly
       else 
         raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
      end

      response.render_table(data_type) unless options.list?

      return response
    end

    # TODO: Duplicate of library import ... should we delete this one?
    desc "import REMOTE-SERVICE-NAME [library_id]", "Import remote service module into library"
    def import(service_module_name,library_id=nil)
      post_body = {
       :remote_module_name => service_module_name
      }
      post_body.merge!(:library_id => library_id) if library_id
      response = post rest_url("service_module/import"), post_body
      @@invalidate_map << :service_module

      return response
    end

    desc "SERVICE-NAME/ID export", "Export service module to remote repo"
    def export(service_module_id)
      post_body = {
       :service_module_id => service_module_id
      }
      post rest_url("service_module/export"), post_body
    end

    desc "SERVICE-NAME/ID push-to-remote", "Push local copy of service module to remote repository."
    def push_to_remote(service_module_id)
      post_body = {
       :service_module_id => service_module_id
      }
      post rest_url("service_module/push_to_remote"), post_body
    end

    desc "SERVICE-NAME/ID pull-from-remote", "Update local service module from remote repository."
    def pull_from_remote(service_module_id)
      post_body = {
       :service_module_id => service_module_id
      }
      post rest_url("service_module/pull_from_remote"), post_body
    end

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    #
    desc "SERVICE-NAME/ID clone [VERSION]", "Clone into client the service module files"
    def clone(arg1,arg2=nil,internal_trigger=false)
      service_module_id,version = (arg2.nil? ? [arg1] : [arg2,arg1]) 
      clone_aux(:service_module,service_module_id,version,internal_trigger)
    end

    desc "SERVICE-NAME/ID push-clone-changes [VERSION]", "Push changes from local copy of service module to server"
    def push_clone_changes(arg1,arg2=nil)
      service_module_id,version = (arg2.nil? ? [arg1] : [arg2,arg1])
      push_clone_changes_aux(:service_module,service_module_id,version)
    end


    # TODO: Check to see if we are deleting this
    desc "create SERVICE-NAME [library_id]", "Create an empty service module in library"
    def create(module_name,library_id=nil)
      post_body = {
       :module_name => module_name
      }
      post_body.merge!(:library_id => library_id) if library_id
      response = post rest_url("service_module/create"), post_body
      # when changing context send request for getting latest services instead of getting from cache
      @@invalidate_map << :service_module

      return response
    end

    desc "delete SERVICE-ID", "Delete service module and all items contained in it"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete(service_module_id)
      unless options.force?
        # Ask user if really want to delete service module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete service-module '#{service_module_id}' and all items contained in it?")
      end

      post_body = {
       :service_module_id => service_module_id
      }
      response = post rest_url("service_module/delete"), post_body
      # when changing context send request for getting latest services instead of getting from cache
      @@invalidate_map << :service_module

      return response
    end

    desc "delete-remote REMOTE-MODULE", "Delete remote service module"
    def delete_remote(remote_module_name)
      post_body = {
       :remote_module_name => remote_module_name
      }
      response = post rest_url("service_module/delete_remote"), post_body
      @@invalidate_map << :module_service

      return response
    end

    desc "add-direct-access [PATH-TO-RSA-PUB-KEY]","Adds direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def add_direct_access(path_to_key=nil)
      path_to_key ||= SshProcessing.default_rsa_pub_key_path()
      unless File.file?(path_to_key)
        raise DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        :rsa_pub_key => rsa_pub_key.chomp
      }
      response = post(rest_url("service_module/add_user_direct_access"),post_body)
      return response unless response.ok?
      repo_manager_fingerprint,repo_manager_dns = response.data_ret_and_remove!(:repo_manager_fingerprint,:repo_manager_dns)
      SshProcessing.update_ssh_known_hosts(repo_manager_dns,repo_manager_fingerprint)
      response
    end

    desc "remove-direct-access [PATH-TO-RSA-PUB-KEY]","Removes direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def remove_direct_access(path_to_key=nil)
      path_to_key ||= "#{ENV['HOME']}/.ssh/id_rsa.pub" #TODO: very brittle
      unless File.file?(path_to_key)
        raise  DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        :rsa_pub_key => rsa_pub_key.chomp
      }
      post rest_url("service_module/remove_user_direct_access"), post_body
    end

    desc "create-jenkins-project SERVICE-ID", "Create Jenkins project for service module"
    def create_jenkins_project(service_module_id)
      #require put here so dont necessarily have to install jenkins client gems

      dtk_require_from_base('command_helpers/jenkins_client')
      response = get rest_url("service_module/deprecate_workspace_branch_info/#{service_module_id.to_s}")
      unless response.ok?
        errors_message = ''
        response['errors'].each { |error| errors_message += ", reason='#{error['code']}' message='#{error['message']}'" }
        raise DTK::Client::DtkError, "Invalid jenkins response#{errors_message}"
      end
      module_name,repo_url,branch = response.data_ret_and_remove!(:module_name,:repo_url,:workspace_branch)
      JenkinsClient.create_service_module_project?(service_module_id,module_name,repo_url,branch)
      #TODO: right now JenkinsClient wil throw error if problem; better to create an error resonse
      response
    end
        
  end
end

