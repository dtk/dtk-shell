#TODO: putting in version as hidden coption that can be enabled when code ready
#TODO: may be consistent on whether service module id or service module name used as params
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
  class Service < CommandBaseThor

    no_tasks do
      include CloneMixin
      include PushToRemoteMixin
      include PullFromRemoteMixin
      include PushCloneChangesMixin
    end

    def self.pretty_print_cols()
      PPColumns.get(:service_module)
    end

    def self.whoami()
      return :service_module, "service_module/list", nil
    end

    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :command_only => {
          :self => [
            ["list"," list --remote --list","# List service modules (local/remote)"]
          ]
        },
        :identifier_only => {
          :self      => [
            ["list","list [assembly-templates] --remote --list","# List service modules (local/remote) or assembly/component templates associated with service module."]
          ]
        }
      })
    end
    
    ##MERGE-QUESTION: need to add options of what info is about
    desc "SERVICE-NAME/ID info", "Provides information about specified service module"
    def info(context_params)
      service_module_id = context_params.retrieve_arguments([:service_name!],method_argument_names)
      post_body = {
       :service_module_id => service_module_id
      }
      response = post rest_url('service_module/info')
    end

    desc "[SERVICE-NAME/ID] list [assembly-templates] --remote --list","List service modules (local/remote) or assembly/component templates associated with service module."
    method_option :list, :type => :boolean, :default => false
    method_option :remote, :type => :boolean, :default => false
    def list(context_params)
      service_module_id, about = context_params.retrieve_arguments([:service_id, :option_1],method_argument_names)

      post_body = {
       :service_module_id => service_module_id,
      }
      if about.nil?
        action = (options.remote? ? "list_remote" : "list")
        response = post rest_url("service_module/#{action}")
        data_type = :module
      else
        if options.remote?
          # TODO: this is temp; will shortly support this
          raise DTK::Client::DtkValidationError, "Not supported '--remote' option when listing service module assemblies or component templates"
        end

        unless service_module_id
          raise DTK::Client::DtkValidationError, "Service module is required to list requested '#{about}'"
        end

        case about
         when "assembly-templates"
          data_type = :assembly_template
          response = post rest_url("service_module/list_assemblies"), post_body
         else 
          raise DTK::Client::DtkValidationError, "Not supported type '#{about}' for given command."
        end
      end

      response.render_table(data_type) unless options.list?

      response
    end

    desc "import REMOTE-SERVICE-NAME", "Import remote service module into local environment"
    version_method_option
    def import(context_params)

      remote_module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      local_module_name = remote_module_name
      version = options["version"]
      if clone_dir = Helper(:git_repo).local_clone_dir_exists?(:service_module,local_module_name)
        raise DtkValidationError,"Module's directory (#{clone_dir}) exists on client. To import this needs to be renamed or removed"
      end

      post_body = {
        :remote_module_name => remote_module_name,
        :local_module_name => local_module_name
      }
      response = post rest_url("service_module/import"), post_body
      @@invalidate_map << :service_module

      return response unless response.ok?
      module_name,repo_url,branch = response.data(:module_name,:repo_url,:workspace_branch)
      Helper(:git_repo).create_clone_with_branch(:service_module,module_name,repo_url,branch,version)
    end

    desc "SERVICE-NAME/ID import-version VERSION", "Import a specfic version from a linked service module"
    def import_version(context_params)
      service_module_id,version = context_params.retrieve_arguments([:service_id!,:option_1!],method_argument_names)
      post_body = {
        :service_module_id => service_module_id,
        :version => version
      }
      response = post rest_url("service_module/import_version"), post_body
      @@invalidate_map << :module_service

      return response unless response.ok?
      module_name,repo_url,branch,version = response.data(:module_name,:repo_url,:workspace_branch,:version)
      #TODO: need to check if local clone directory exists
      Helper(:git_repo).create_clone_with_branch(:service_module,module_name,repo_url,branch,version)
    end

    desc "SERVICE-NAME/ID export", "Export service module to remote repo"
    def export(context_params)
      service_module_id = context_params.retrieve_arguments([:service_id!],method_argument_names)

      post_body = {
       :service_module_id => service_module_id
      }
      post rest_url("service_module/export"), post_body
    end

    desc "SERVICE-NAME/ID push-to-remote [-v VERSION]", "Push local copy of service module to remote repository."
    version_method_option
    def push_to_remote(context_params)
      service_module_id = context_params.retrieve_arguments([:service_id!],method_argument_names)
      push_to_remote_aux(:service_module,service_module_id,options["version"])
    end

    desc "SERVICE-NAME/ID pull-from-remote [-v VERSION]", "Update local service module from remote repository."
    version_method_option
    def pull_from_remote(context_params)
      service_module_id = context_params.retrieve_arguments([:service_id!],method_argument_names)
      pull_from_remote_aux(:service_module,service_module_id,options["version"])
    end

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    #
    desc "SERVICE-NAME/ID clone [-v VERSION]", "Clone into client the service module files"
    version_method_option
    def clone(context_params, internal_trigger=false)
      service_module_id = context_params.retrieve_arguments([:service_id!],method_argument_names)
      version = options["version"]
      clone_aux(:service_module,service_module_id,version,internal_trigger)
    end

    desc "SERVICE-NAME/ID push-clone-changes [-v VERSION]", "Push changes from local copy of service module to server"
    version_method_option
    def push_clone_changes(context_params)
      service_module_id = context_params.retrieve_arguments([:service_id!],method_argument_names)
      version = options["version"]
      push_clone_changes_aux(:service_module,service_module_id,version)
    end

    desc "SERVICE-NAME/ID create-new-version NEW-VERSION", "Snapshot current state of module as a new version"
    def create_new_version(context_params)
      service_module_id,version = context_params.retrieve_arguments([:service_id!,:option_1!],method_argument_names)
      post_body = {
        :service_module_id => service_module_id,
        :version => version
      }

      post rest_url("service_module/create_new_version"), post_body
    end

    desc "SERVICE-NAME/ID set-module-version COMPONENT-MODULE-NAME VERSION", "Set the version of the component module to use in the service's assemblies"
    def set_module_version(context_params)
      service_module_id,component_module_id,version = context_params.retrieve_arguments([:service_id!,:option_1!,:option_2!],method_argument_names)
      post_body = {
        :service_module_id => service_module_id,
        :component_module_id => component_module_id,
        :version => version                                                                                          
      }
      response = post rest_url("service_module/set_component_module_version"), post_body
      @@invalidate_map << :service_module
      return response unless response.ok?()
      module_name,commit_sha,workspace_branch = response.data(:module_name,:commit_sha,:workspace_branch)
      Helper(:git_repo).synchronize_clone(:service_module,module_name,commit_sha,:local_branch=>workspace_branch)
    end

    # TODO: put in two versions, one that creates empty and anotehr taht creates from local dir; use --empty flag
    desc "create SERVICE-NAME", "Create an empty service module"
    def create(context_params)
      module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      post_body = {
       :module_name => module_name
      }
      response = post rest_url("service_module/create"), post_body
      # when changing context send request for getting latest services instead of getting from cache
      @@invalidate_map << :service_module

      return response
    end

    desc "delete SERVICE-IDENTIFIER", "Delete service module and all items contained in it"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete(context_params)
      service_module_id = context_params.retrieve_arguments([:option_1!],method_argument_names)

      unless options.force?
        # Ask user if really want to delete service module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete service-module '#{service_module_id}' and all items contained in it"+'?')
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
    def delete_remote(context_params)
      remote_module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      post_body = {
       :remote_module_name => remote_module_name
      }
      response = post rest_url("service_module/delete_remote"), post_body
      @@invalidate_map << :module_service

      return response
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
      return response unless response.ok?
      repo_manager_fingerprint,repo_manager_dns = response.data_ret_and_remove!(:repo_manager_fingerprint,:repo_manager_dns)
      SshProcessing.update_ssh_known_hosts(repo_manager_dns,repo_manager_fingerprint)
      response
    end

    desc "remove-direct-access [PATH-TO-RSA-PUB-KEY]","Removes direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def remove_direct_access(context_params)
      path_to_key = context_params.retrieve_arguments([:option_1],method_argument_names)
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
=begin
    desc "SERVICE-NAME/ID assembly-templates list", "List assembly templates optionally filtered by service ID/NAME." 
    def assembly_template(context_params)

      service_id, method_name = context_params.retrieve_arguments([:service_name!, :option_1!],method_argument_names)

      options_args = ["-s", service_id]
      
      entity_name = "assembly_template"
      load_command(entity_name)
      entity_class = DTK::Client.const_get "#{cap_form(entity_name)}"
      
      response = entity_class.execute_from_cli(@conn, method_name, DTK::Shell::ContextParams.new, options_args, false)

    end
=end
=begin
TODO: needs to be rewritten
    desc "create-jenkins-project SERVICE-ID", "Create Jenkins project for service module"
    def create_jenkins_project(context_params)
      service_module_id = context_params.retrieve_arguments([:service_id],method_argument_names)
      #require put here so dont necessarily have to install jenkins client gems

      dtk_require_from_base('command_helpers/jenkins_client')
      response = get rest_url("service_module/workspace_branch_info/#{service_module_id.to_s}")
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
=end        
  end
end

