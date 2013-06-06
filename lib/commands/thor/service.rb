#TODO: putting in version as hidden coption that can be enabled when code ready
#TODO: may be consistent on whether service module id or service module name used as params
dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/push_to_remote')
dtk_require_common_commands('thor/pull_from_remote')
dtk_require_common_commands('thor/push_clone_changes')
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_from_base("commands/thor/assembly_template")
dtk_require_common_commands('thor/task_status')
dtk_require_common_commands('thor/set_required_params')

module DTK::Client
  class Service < CommandBaseThor

    no_tasks do
      include CloneMixin
      include PushToRemoteMixin
      include PullFromRemoteMixin
      include PushCloneChangesMixin

      def get_service_module_name(service_module_id)
        service_module_name = nil
        # TODO: See with Rich if there is better way to resolve this
        response = DTK::Client::CommandBaseThor.get_cached_response(:module, "service_module/list")

        if response.ok?
          unless response['data'].nil?
            response['data'].each do |module_item|
              if service_module_id.to_i == (module_item['id'])
                service_module_name = module_item['display_name']
                break
              end
            end
          end
        end

        raise DTK::Client::DtkError, "Not able to resolve module name, please provide module name." if service_module_name.nil?
        return service_module_name
      end

    end

    def self.valid_children()
      [:"assembly-template"]
    end

    def self.all_children()
      [:"assembly-template"]
    end

    def self.valid_child?(name_of_sub_context)
      return Service.valid_children().include?(name_of_sub_context.to_sym)
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
            ["list"," list --remote","# List service modules (local/remote)"]
          ],
          :"assembly-template" => [
            ["list","list","# List assembly templates for given service"]
          ]
        },
        :identifier_only => {
          :self      => [
            ["list-assembly-templates","list-assembly-templates","# List assembly templates associated with service module."],
            ["list-modules","list-modules","# List modules associated with service module."]
          ],
          :"assembly-template" => [
            ["info","info","# Info for given assembly template in current service"],
            ["stage", "stage [INSTANCE-NAME] -t [TARGET-NAME/ID]", "# Stage assembly template in target."],
            ["deploy","deploy [-v VERSION] [INSTANCE-NAME] [-m COMMIT-MSG]", "# Stage and deploy assembly template in target."],
            ["list-nodes","list-nodes", "# List all nodes for given assembly template."],
            ["list-components","list-components", "# List all components for given assembly template."]
          ]
        }

      })
    end
    
    ##MERGE-QUESTION: need to add options of what info is about
    desc "SERVICE-NAME/ID info", "Provides information about specified service module"
    def info(context_params)
      if context_params.is_there_identifier?(:assembly_template) 
        response = DTK::Client::ContextRouter.routeTask("assembly_template", "info", context_params, @conn)
      else  
        service_module_id = context_params.retrieve_arguments([:service_id!],method_argument_names)
        post_body = {
         :service_module_id => service_module_id
        }

        response = post rest_url('service_module/info'), post_body
      end
    end

    desc "SERVICE-NAME/ID list-assembly-templates","List assembly templates associated with service."
    method_option :remote, :type => :boolean, :default => false
    def list_assembly_templates(context_params)
      context_params.method_arguments = ["assembly-templates"]
      list(context_params)
    end

    desc "SERVICE-NAME/ID list-modules","List modules associated with service."
    method_option :remote, :type => :boolean, :default => false
    def list_modules(context_params)
      context_params.method_arguments = ["modules"]
      list(context_params)
    end

    desc "list --remote","List service modules (local/remote)."
    method_option :remote, :type => :boolean, :default => false
    def list(context_params)
      service_module_id, about = context_params.retrieve_arguments([:service_id, :option_1],method_argument_names)

      if context_params.is_there_command?(:"assembly-template")
        about = "assembly-templates"
      end

      # If user is on service level, list task can't have about value set
      if (context_params.last_entity_name == :service) and about.nil?
        data_type = :module
        action    = options.remote? ? "list_remote" : "list"
        post_body = {}
 
        response = post rest_url("service_module/#{action}"), post_body
      # If user is on service identifier level, list task can't have '--remote' option.
      else
        # TODO: this is temp; will shortly support this
        raise DTK::Client::DtkValidationError, "Not supported '--remote' option when listing service module assemblies, component templates or modules" if options.remote?
        raise DTK::Client::DtkValidationError, "Not supported type '#{about}' for list for current context level. Possible type options: 'assembly-templates'" unless(about == "assembly-templates" || about == "modules")
        
        if about
          case about
          when "assembly-templates"
            data_type        = :assembly_template
            action           = "list_assemblies"
            post_body        = { :service_module_id => service_module_id }

            response = post rest_url("service_module/#{action}"), post_body
          when "modules"
            data_type        = :component
            action           = "list_component_modules"
            post_body        = { :service_module_id => service_module_id }

            response = post rest_url("service_module/#{action}"), post_body
          else
            raise_validation_error_method_usage('list')
          end 
        end
      end

      response.render_table(data_type) unless response.nil?

      response
    end

    desc "import-r8n REMOTE-SERVICE-NAME", "Import remote service module into local environment"
    version_method_option
    def import_r8n(context_params)

      remote_module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      remote_namespace, local_module_name = get_namespace_and_name(remote_module_name)

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

    desc "SERVICE-NAME/ID export [[NAME-SPACE/]REMOTE-MODULE-NAME]","Export service module to remote repository"
    def export(context_params)
      service_module_id, input_remote_name = context_params.retrieve_arguments([:service_id!, :option_1],method_argument_names)

      remote_namespace, remote_name = get_namespace_and_name(input_remote_name)

      post_body = {
       :service_module_id          => service_module_id,
       :remote_component_name      => remote_name,
       :remote_component_namespace => remote_namespace
      }

      post rest_url("service_module/export"), post_body
    end

    desc "SERVICE-NAME/ID push-to-remote [-n NAMESPACE] [-v VERSION]", "Push local copy of service module to remote repository."
    version_method_option
        method_option "namespace",:aliases => "-n",
        :type => :string, 
        :banner => "NAMESPACE",
        :desc => "Remote namespace"
    def push_to_remote(context_params)
      service_module_id, service_name = context_params.retrieve_arguments([:service_id!, :service_name],method_argument_names)
      push_to_remote_aux(:service_module, service_module_id, service_name, options["namespace"], options["version"])
    end

    desc "SERVICE-NAME/ID pull-from-remote [-v VERSION]", "Update local service module from remote repository."
    version_method_option
    def pull_from_remote(context_params)
      service_module_id = context_params.retrieve_arguments([:service_id!],method_argument_names)
      pull_from_remote_aux(:service_module,service_module_id,options["namespace"],options["version"])
    end

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    #
    desc "SERVICE-NAME/ID clone [-v VERSION] [-n]", "Clone into client the service module files. Use -n to skip edit prompt."
    method_option :skip_edit, :aliases => '-n', :type => :boolean, :default => false
    version_method_option
    def clone(context_params, internal_trigger=false)
      service_module_id   = context_params.retrieve_arguments([:service_id!],method_argument_names)
      service_module_name = context_params.retrieve_arguments([:service_id],method_argument_names)
      version             = options["version"]
      internal_trigger    = true if options.skip_edit?

      # if this is not name it will not work, we need module name
      if service_module_name.to_s =~ /^[0-9]+$/
        service_module_id   = service_module_name
        service_module_name = get_service_module_name(service_module_id)
      end

      modules_path    = OsUtil.service_clone_location()
      module_location = "#{modules_path}/#{service_module_name}#{version && "-#{version}"}"

      raise DTK::Client::DtkValidationError, "Trying to clone a service module '#{service_module_name}#{version && "-#{version}"}' that exists already!" if File.directory?(module_location)
      clone_aux(:service_module,service_module_id,version,internal_trigger)
    end

    desc "SERVICE-NAME/ID edit [-v VERSION]","Switch to unix editing for given module."
    version_method_option
    def edit(context_params)
      service_module_id   = context_params.retrieve_arguments([:service_id!],method_argument_names)
      service_module_name = context_params.retrieve_arguments([:service_id],method_argument_names)
      version             = options["version"]

      # if this is not name it will not work, we need module name
      if service_module_name.to_s =~ /^[0-9]+$/
        service_module_id   = service_module_name
        service_module_name = get_service_module_name(service_module_id)
      end

      modules_path    = OsUtil.service_clone_location()
      module_location = "#{modules_path}/#{service_module_name}#{version && "-#{version}"}"

      # check if there is repository cloned 
      unless File.directory?(module_location)
        if Console.confirmation_prompt("Edit not possible, module '#{service_module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          # context_params_for_service = create_context_for_module(service_module_name, "service")
          # response = clone(context_params_for_service,true)
          response = clone_aux(:service_module,service_module_id,version,true)
          # if error return
          unless response.ok?
            return response
          end
        else
          # user choose not to clone needed module
          return
        end
      end

      # here we should have desired module cloned
      Console.unix_shell(module_location, service_module_id, :service_module, version)
      grit_adapter = DTK::Common::GritAdapter::FileAccess.new(module_location)

      if grit_adapter.changed?
        grit_adapter.print_status

        # check to see if auto commit flag
        auto_commit  = ::DTK::Configuration.get(:auto_commit_changes)
        confirmed_ok = false

        # if there is no auto commit ask for confirmation
        unless auto_commit
          confirmed_ok = Console.confirmation_prompt("Would you like to commit and push following changes (keep in mind this will commit ALL above changes)?") 
        end

        if (auto_commit || confirmed_ok)
          puts "[NOTICE] You are using auto-commit option, all changes you have made will be commited."
          commit_msg = user_input("Commit message")
          grit_adapter.add_remove_commit_all(commit_msg)
          grit_adapter.push()
        end

        puts "DTK SHELL TIP: Adding the client configuration parameter <config param name>=true will have the client automatically commit each time you exit edit mode" unless auto_commit
      else
        puts "No changes to repository"
      end

      #grit_adapter.add_file("baba.xml")
      #grit_adapter.commit("nesto")

      #repo = Grit::Repo.new(location)
      #repo.status.files.select { |k,v| (v.type =~ /(M|A|D)/ || v.untracked) }

    end

    desc "SERVICE-NAME/ID create-version NEW-VERSION", "Snapshot current state of module as a new version"
    def create_version(context_params)
      service_module_id,version = context_params.retrieve_arguments([:service_id!,:option_1!],method_argument_names)
      service_module_name = nil

      post_body = {
        :service_module_id => service_module_id,
        :version => version
      }

      response = post rest_url("service_module/create_new_version"), post_body
      return response unless response.ok?

      if service_module_id.to_s =~ /^[0-9]+$/
        service_module_name = get_service_module_name(service_module_id)
      end

      modules_path    = OsUtil.service_clone_location()
      module_location = "#{modules_path}/#{service_module_name}#{version && "-#{version}"}"

      raise DTK::Client::DtkValidationError, "Trying to clone a service module '#{service_module_name}#{version && "-#{version}"}' that exists already!" if File.directory?(module_location)
      clone_aux(:service_module,service_module_id,version,true)     
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
    desc "import SERVICE-NAME", "Create new service module from local clone"
    def import(context_params)
      module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      # first check that there is a directory there and it is not already a git repo, and it ha appropriate content
      response = Helper(:git_repo).check_local_dir_exists_with_content(:service_module,module_name)
      return response unless response.ok?
      service_directory = response.data(:module_directory)

      # first call to create empty module
      response = post rest_url("service_module/create"), { :module_name => module_name }        
      return response unless response.ok?
      @@invalidate_map << :service_module

      # initial commit for given service module
      service_module_id, repo_info, module_id = response.data(:service_module_id, :repo_info)
      repo_url,repo_id,module_id,branch = [:repo_url,:repo_id,:module_id,:workspace_branch].map { |k| repo_info[k.to_s] }
      response = Helper(:git_repo).initialize_client_clone_and_push(:service_module, module_name,branch,repo_url)
      return response unless response.ok?
      repo_obj,commit_sha =  response.data(:repo_obj,:commit_sha)
            
      context_params.add_context_to_params("service", "service", module_id)
      push_clone_changes(context_params)
    end


    desc "SERVICE-NAME/ID push-clone-changes [-v VERSION] [-m COMMIT-MSG]", "Push changes from local copy of service module to server"
    version_method_option
    method_option "message",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def push_clone_changes(context_params)
      service_module_id = context_params.retrieve_arguments([:service_id!],method_argument_names)
      version = options["version"]
      push_clone_changes_aux(:service_module,service_module_id,version)
    end

    desc "delete SERVICE-IDENTIFIER [-y] [-p]", "Delete service module and all items contained in it. Optional parameter [-p] is to delete local directory."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    def delete(context_params)
      module_location, modules_path = nil, nil
      service_module_id = context_params.retrieve_arguments([:option_1!],method_argument_names)

      unless options.force?
        # Ask user if really want to delete service module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete service-module '#{service_module_id}' and all items contained in it"+'?')
      end

      post_body = {
        :service_module_id => service_module_id
      }
      response = post rest_url("service_module/delete"), post_body
      return response unless response.ok?
      module_name = response.data(:module_name)
      
      # when changing context send request for getting latest services instead of getting from cache
      @@invalidate_map << :service_module

      # delete local module directory
      if options.purge?
        service_module_id = get_service_module_name(service_module_id) if service_module_id.to_s =~ /^[0-9]+$/
        modules_path    = OsUtil.service_clone_location()
        module_location = "#{modules_path}/#{service_module_id}" unless service_module_id.nil?

        raise DTK::Client::DtkValidationError, "Trying to delete local directory ('#{module_location}') that does not exist." unless File.directory?(module_location)
        
        module_versions = Dir.entries(modules_path).select{|a| a.match(/#{service_module_id}-\d.\d.\d/)}

        unless (module_location.nil? || ("#{modules_path}/" == module_location))
          FileUtils.rm_rf("#{module_location}") if File.directory?(module_location)

          module_versions.each do |version|
            FileUtils.rm_rf("#{modules_path}/#{version}") if File.directory?("#{modules_path}/#{version}")
          end
        end
      end

      return response
    end

    desc "delete-remote REMOTE-SERVICE-NAME", "Delete remote service module"
    def delete_remote(context_params)
      remote_service_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      post_body = {
       :remote_service_name => remote_service_name
      }
      response = post rest_url("service_module/delete_remote"), post_body
      @@invalidate_map << :module_service

      return response
    end

    # desc "add-direct-access [PATH-TO-RSA-PUB-KEY]","Adds direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    # def add_direct_access(context_params)
    #   path_to_key = context_params.retrieve_arguments([:option_1],method_argument_names)
    #   path_to_key ||= SshProcessing.default_rsa_pub_key_path()
    #   unless File.file?(path_to_key)
    #     raise DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
    #   end
    #   rsa_pub_key = File.open(path_to_key){|f|f.read}
    #   post_body = {
    #     :rsa_pub_key => rsa_pub_key.chomp
    #   }
    #   response = post(rest_url("service_module/add_user_direct_access"),post_body)
    #   return response unless response.ok?
    #   puts "#{response.inspect}"
    #   repo_manager_fingerprint,repo_manager_dns = response.data_ret_and_remove!(:repo_manager_fingerprint,:repo_manager_dns)
    #   SshProcessing.update_ssh_known_hosts(repo_manager_dns,repo_manager_fingerprint)
    #   response
    # end

    # desc "remove-direct-access [PATH-TO-RSA-PUB-KEY]","Removes direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    # def remove_direct_access(context_params)
    #   path_to_key = context_params.retrieve_arguments([:option_1],method_argument_names)
    #   path_to_key ||= "#{ENV['HOME']}/.ssh/id_rsa.pub" #TODO: very brittle
    #   unless File.file?(path_to_key)
    #     raise  DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
    #   end
    #   rsa_pub_key = File.open(path_to_key){|f|f.read}
    #   post_body = {
    #     :rsa_pub_key => rsa_pub_key.chomp
    #   }
    #   post rest_url("service_module/remove_user_direct_access"), post_body
    # end
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

