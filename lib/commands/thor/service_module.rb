#TODO: putting in version as hidden coption that can be enabled when code ready
#TODO: may be consistent on whether service module id or service module name used as params
dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_from_base('command_helpers/service_importer')
dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/push_to_remote')
dtk_require_common_commands('thor/pull_from_remote')
dtk_require_common_commands('thor/push_clone_changes')
dtk_require_common_commands('thor/edit')
dtk_require_common_commands('thor/reparse')
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_from_base("commands/thor/assembly")
dtk_require_common_commands('thor/task_status')
dtk_require_common_commands('thor/set_required_params')
dtk_require_common_commands('thor/purge_clone')
dtk_require_dtk_common('grit_adapter')

module DTK::Client
  class ServiceModule < CommandBaseThor

    no_tasks do
      include CloneMixin
      include PushToRemoteMixin
      include PullFromRemoteMixin
      include PushCloneChangesMixin
      include EditMixin
      include ReparseMixin
      include ServiceImporter
      include PurgeCloneMixin

      def get_service_module_name(service_module_id)
        get_name_from_id_helper(service_module_id)
      end
    end

    def self.valid_children()
      [:"assembly"]
    end

    def self.all_children()
      [:"assembly"]
    end

    def self.valid_child?(name_of_sub_context)
      return ServiceModule.valid_children().include?(name_of_sub_context.to_sym)
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
            ["list"," list [--remote] [--diff]","# List service modules (local/remote). Use --diff to compare loaded and remote modules."]
          ],
          :"assembly" => [
            ["list","list","# List assemblies for given service module."]
          ]
        },
        :identifier_only => {
          :self      => [
            ["list-assemblies","list-assemblies","# List assemblies associated with service module."],
            ["list-modules","list-modules","# List modules associated with service module."]
          ],
          :"assembly" => [
            ["info","info","# Info for given assembly in current service module."],
            ["stage", "stage [INSTANCE-NAME] -t [TARGET-NAME/ID]", "# Stage assembly in target."],
            ["deploy","deploy [-v VERSION] [INSTANCE-NAME] [-m COMMIT-MSG]", "# Stage and deploy assembly in target."],
            ["list-nodes","list-nodes", "# List all nodes for given assembly."],
            ["list-components","list-components", "# List all components for given assembly."]
          ]
        }

      })
    end
    
    ##MERGE-QUESTION: need to add options of what info is about
    desc "SERVICE-MODULE-NAME/ID info", "Provides information about specified service module"
    def info(context_params)
      #TODO Aldin
      if context_params.is_there_identifier?(:assembly)
        response = DTK::Client::ContextRouter.routeTask("assembly", "info", context_params, @conn)
      else  
        service_module_id = context_params.retrieve_arguments([:service_module_id!],method_argument_names)
        
        post_body = {
         :service_module_id => service_module_id
        }

        response = post rest_url('service_module/info'), post_body
        response.render_custom_info("module")
      end
    end

    desc "SERVICE-MODULE-NAME/ID list-assemblies","List assembly templates associated with service module."
    method_option :remote, :type => :boolean, :default => false
    def list_assemblies(context_params)
      context_params.method_arguments = ["assembly-templates"]
      list(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID list-modules","List modules associated with service module."
    method_option :remote, :type => :boolean, :default => false
    def list_modules(context_params)
      context_params.method_arguments = ["modules"]
      list(context_params)
    end

    desc "list [--remote] [--diff]","List service modules (local/remote). Use --diff to compare loaded and remote modules."
    method_option :remote, :type => :boolean, :default => false
    method_option :diff, :type => :boolean, :default => false
    def list(context_params)
      service_module_id, about, service_module_name = context_params.retrieve_arguments([:service_module_id, :option_1, :option_2],method_argument_names)
      datatype = nil

      if context_params.is_there_command?(:"assembly")
        about = "assembly"
      end

      if service_module_id.nil? && !service_module_name.nil?
        service_module_id = service_module_name
      end
      
      # If user is on service level, list task can't have about value set
      if (context_params.last_entity_name == :"service-module") and about.nil?
        action    = options.remote? ? "list_remote" : "list"
        post_body = (options.remote? ? { :rsa_pub_key => SshProcessing.rsa_pub_key_content() } : {:detail_to_include => ["remotes","versions"]})
        post_body[:diff] = options.diff? ? options.diff : {}
        
        response = post rest_url("service_module/#{action}"), post_body
      # If user is on service identifier level, list task can't have '--remote' option.
      else
        # TODO: this is temp; will shortly support this
        raise DTK::Client::DtkValidationError.new("Not supported '--remote' option when listing service module assemblies, component templates or modules", true) if options.remote?
        raise DTK::Client::DtkValidationError.new("Not supported type '#{about}' for list for current context level. Possible type options: 'assembly'", true) unless(about == "assembly" || about == "modules")
      
        if about
          case about
          when "assembly"
            data_type        = :assembly_template
            action           = "list_assemblies"
          when "modules"
            data_type        = options.remote? ? :component_remote : :component
            action           = "list_component_modules"
          else
            raise_validation_error_method_usage('list')
          end 
        end
        response = post rest_url("service_module/#{action}"), { :service_module_id => service_module_id }
      end
      return response unless response.ok?
      
      response.render_table(data_type) unless response.nil?

      response
    end

    desc "SERVICE-MODULE-NAME/ID list-instances","List all versions associated with this service module."
    def list_instances(context_params)
      service_module_id = context_params.retrieve_arguments([:service_module_id!],method_argument_names)
      post_body = {
        :service_module_id => service_module_id,
      }
      response = post rest_url("service_module/list_instances"), post_body
      
      response.render_table(:assembly_template)
    end

    desc "SERVICE-MODULE-NAME/ID list-versions","List all versions associated with this service module."
    def list_versions(context_params)
      service_module_id = context_params.retrieve_arguments([:service_module_id!],method_argument_names)
      post_body = {
        :service_module_id => service_module_id,
        :detail_to_include => ["remotes"],
        :rsa_pub_key => SshProcessing.rsa_pub_key_content()
      }
      response = post rest_url("service_module/versions"), post_body

      response.render_table(:module_version)
    end

    desc "import-dtkn REMOTE-SERVICE-MODULE-NAME [-y] [-i]", "Import remote service module into local environment. -y will automatically clone component modules. -i will ignore component import error."
    version_method_option
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :ignore, :aliases => '-i', :type => :boolean, :default => false
    def import_dtkn(context_params)
      create_missing_clone_dirs()
      check_direct_access(::DTK::Client::Configurator.check_direct_access)
      remote_module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      ignore_component_error = options.ignore?
      
      remote_namespace, local_module_name = get_namespace_and_name(remote_module_name)

      version = options["version"]
      if clone_dir = Helper(:git_repo).local_clone_dir_exists?(:service_module,local_module_name)
        raise DtkValidationError,"Module's directory (#{clone_dir}) exists on client. To import this needs to be renamed or removed."
      end

      post_body = {
        :remote_module_name => remote_module_name,
        :local_module_name => local_module_name,
        :rsa_pub_key => SshProcessing.rsa_pub_key_content()
      }
      
      response = post rest_url("service_module/import"), post_body

      # case when we need to import additional components
      if (response.ok? && (missing_components = response.data(:missing_module_components)))
        opts = {:do_not_raise=>true}
        module_opts = ignore_component_error ? opts.merge(:ignore_component_error => true) : opts.merge(:additional_message=>true)
        trigger_module_component_import(missing_components,module_opts)
        puts "Resuming DTK network import for service module '#{remote_module_name}' ..."
        # repeat import call for service
        post_body.merge!(opts)
        response = post rest_url("service_module/import"), post_body
      end
      
      return response unless response.ok?
      @@invalidate_map << :service_module

      if error = response.data(:dsl_parsed_info)
        dsl_parsed_message = ServiceImporter.error_message(remote_module_name, error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red) 
      end

      service_module_id, module_name, namespace, repo_url, branch = response.data(:module_id, :module_name, :namespace, :repo_url, :workspace_branch)
      response = Helper(:git_repo).create_clone_with_branch(:service_module,module_name,repo_url,branch,version)
      resolve_missing_components(service_module_id, module_name, namespace, options.force?)

      return response
    end

    desc "SERVICE-MODULE-NAME/ID validate-model [-v VERSION]", "Check the DSL Model for Errors"
    version_method_option
    def validate_model(context_params)
      service_module_id, service_module_name = context_params.retrieve_arguments([:service_module_id!, :service_module_name],method_argument_names)
      version = options["version"]

      if service_module_name.to_s =~ /^[0-9]+$/
        service_module_id   = service_module_name
        service_module_name = get_service_module_name(service_module_id)
      end

      modules_path    = OsUtil.service_clone_location()
      module_location = "#{modules_path}/#{service_module_name}#{version && "-#{version}"}"

      raise DTK::Client::DtkValidationError, "Unable to parse service '#{service_module_name}#{version && "-#{version}"}' that doesn't exist on your local machine!" unless File.directory?(module_location)

      reparse_aux(module_location)
    end

    desc "SERVICE-MODULE-NAME/ID import-version VERSION", "Import a specfic version from a linked service module"
    def import_version(context_params)
      service_module_id,version = context_params.retrieve_arguments([:service_module_id!,:option_1!],method_argument_names)
      post_body = {
        :service_module_id => service_module_id,
        :version => version
      }
      response = post rest_url("service_module/import_version"), post_body
      @@invalidate_map << :module_service

      return response unless response.ok?
      module_name,repo_url,branch,version = response.data(:module_name,:repo_url,:workspace_branch,:version)

      if error = response.data(:dsl_parsed_info)
        dsl_parsed_message = ServiceImporter.error_message("#{module_name}-#{version}", error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red) 
      end

      #TODO: need to check if local clone directory exists
      Helper(:git_repo).create_clone_with_branch(:service_module,module_name,repo_url,branch,version)
    end

    desc "SERVICE-MODULE-NAME/ID create-on-dtkn [[NAME-SPACE/]REMOTE-MODULE-NAME]","Export service module to remote repository"
    def create_on_dtkn(context_params)
      service_module_id, input_remote_name = context_params.retrieve_arguments([:service_module_id!, :option_1],method_argument_names)

      post_body = {
       :service_module_id => service_module_id,
       :remote_component_name => input_remote_name,
       :rsa_pub_key => SshProcessing.rsa_pub_key_content()
      }

      post rest_url("service_module/export"), post_body
    end

    desc "SERVICE-MODULE-NAME/ID push-to-dtkn [-n NAMESPACE] [-v VERSION]", "Push local copy of service module to remote repository."
    version_method_option
        method_option "namespace",:aliases => "-n",
        :type => :string, 
        :banner => "NAMESPACE",
        :desc => "Remote namespace"
    def push_to_dtkn(context_params)
      service_module_id, service_module_name = context_params.retrieve_arguments([:service_module_id!, :service_module_name],method_argument_names)
      version = options["version"]

      if service_module_name.to_s =~ /^[0-9]+$/
        service_id   = service_module_name
        service_module_name = get_service_module_name(service_id)
      end

      modules_path    = OsUtil.service_clone_location()
      module_location = "#{modules_path}/#{service_module_name}#{version && "-#{version}"}"

      unless File.directory?(module_location)
        if Console.confirmation_prompt("Unable to push to remote because module '#{service_module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          response = clone_aux(:service_module,service_module_id,version,false)
          
          if(response.nil? || response.ok?)
            reparse_aux(module_location)
            push_to_remote_aux(:service_module, service_module_id, service_module_name, options["namespace"], version) if Console.confirmation_prompt("Would you like to push changes to remote"+'?')
          end

          return response
        else
          # user choose not to clone needed module
          return
        end
      end
      
      reparse_aux(module_location)
      push_to_remote_aux(:service_module, service_module_id, service_module_name, options["namespace"], options["version"])
    end

    desc "SERVICE-MODULE-NAME/ID pull-from-dtkn [-v VERSION]", "Update local service module from remote repository."
    version_method_option
    def pull_from_dtkn(context_params)
      service_module_id, service_module_name = context_params.retrieve_arguments([:service_module_id!,:service_module_name],method_argument_names)
      version = options["version"]

      response = pull_from_remote_aux(:service_module,service_module_id,version)
      return response unless response.ok?

      if service_module_name.to_s =~ /^[0-9]+$/
        service_module_id   = service_module_name
        service_module_name = get_service_module_name(service_module_id)
      end

      modules_path    = OsUtil.service_clone_location()
      module_location = "#{modules_path}/#{service_module_name}#{version && "-#{version}"}"

      # server repo needs to be sync with local clone, so we will use push-clone-changes when pull changes from remote to local
      # to automatically sync local with server repo
      push_clone_changes_aux(:service_module,service_module_id,version,nil,true) if File.directory?(module_location)
      Response::Ok.new()
    end

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    #
    desc "SERVICE-MODULE-NAME/ID clone [-v VERSION] [-n]", "Locally clone the service module files. Use -n to skip edit prompt"
    method_option :skip_edit, :aliases => '-n', :type => :boolean, :default => false
    version_method_option
    def clone(context_params, internal_trigger=false)
      service_module_id, service_module_name = context_params.retrieve_arguments([:service_module_id!, :service_module_name],method_argument_names)
      internal_trigger = true if options.skip_edit?
      version          = options["version"]

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

    desc "SERVICE-MODULE-NAME/ID edit [-v VERSION]","Switch to unix editing for given service module."
    version_method_option
    def edit(context_params)
      service_module_id, service_module_name = context_params.retrieve_arguments([:service_module_id!, :service_module_name],method_argument_names)
      version             = options["version"]

      # if this is not name it will not work, we need module name
      if service_module_name.to_s =~ /^[0-9]+$/
        service_module_id   = service_module_name
        service_module_name = get_service_module_name(service_module_id)
      end

      edit_aux(:service_module,service_module_id,service_module_name,version)
    end

    desc "SERVICE-MODULE-NAME/ID create-version NEW-VERSION", "Snapshot current state of service module as a new version"
    def create_version(context_params)
      service_module_id,version = context_params.retrieve_arguments([:service_module_id!,:option_1!],method_argument_names)
      post_body = {
        :service_module_id => service_module_id,
        :rsa_pub_key => SshProcessing.rsa_pub_key_content()
      }
      response = post rest_url("service_module/versions"), post_body
      return response unless response.ok?
      versions = (response.data.first && response.data.first['versions'])||Array.new
      if versions.include?(version)
        return Response::Error::Usage.new("Version #{version} exists already")
      end

      service_module_name = get_service_module_name(service_module_id)
      module_location = OsUtil.module_location(:service_module,service_module_name,version)
      if File.directory?(module_location)
        raise DtkError, "Target service module directory for version #{version} (#{module_location}) exists already; it must be deleted and this comamnd retried"
      end

      post_body = {
        :service_module_id => service_module_id,
        :version => version
      }

      response = post rest_url("service_module/create_new_version"), post_body
      return response unless response.ok?

      internal_trigger = omit_output = true
      clone_aux(:service_module,service_module_name,version,internal_trigger,omit_output)
    end

    desc "SERVICE-MODULE-NAME/ID set-module-version COMPONENT-MODULE-NAME VERSION", "Set the version of the component module to use in the service module's assemblies"
    def set_module_version(context_params)
      service_module_id,component_module_id,version = context_params.retrieve_arguments([:service_module_id!,:option_1!,:option_2!],method_argument_names)
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
    desc "import SERVICE-MODULE-NAME", "Create new service module from local clone"
    def import(context_params)
      module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      # first check that there is a directory there and it is not already a git repo, and it ha appropriate content
      response = Helper(:git_repo).check_local_dir_exists_with_content(:service_module,module_name)
      return response unless response.ok?
      service_directory = response.data(:module_directory)
      
      #check for yaml/json parsing errors before import
      reparse_aux(service_directory)

      # first call to create empty module
      response = post rest_url("service_module/create"), { :module_name => module_name }        
      return response unless response.ok?
      @@invalidate_map << :service_module
      
      if error = response.data(:dsl_parsed_info)
        dsl_parsed_message = ServiceImporter.error_message(module_name, error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red) 
      end

      # initial commit for given service module
      service_module_id, repo_info, module_id = response.data(:service_module_id, :repo_info)
      repo_url,repo_id,module_id,branch = [:repo_url,:repo_id,:module_id,:workspace_branch].map { |k| repo_info[k.to_s] }
      response = Helper(:git_repo).initialize_client_clone_and_push(:service_module, module_name,branch,repo_url,service_directory)
      return response unless response.ok?
      repo_obj,commit_sha =  response.data(:repo_obj,:commit_sha)

      context_params.add_context_to_params(module_name, :"service-module", module_id)
      push(context_params,true)
    end


    desc "SERVICE-MODULE-NAME/ID push [-v VERSION] [-m COMMIT-MSG]", "Push changes from local copy of service module to server"
    version_method_option
    method_option "message",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    #hidden option for dev
    method_option 'force-parse', :aliases => '-f', :type => :boolean, :default => false
    def push(context_params, internal_trigger=false)
      service_module_id, service_module_name = context_params.retrieve_arguments([:service_module_id!, :service_module_name],method_argument_names)
      version = options["version"]

      if service_module_name.to_s =~ /^[0-9]+$/
        service_module_id   = service_module_name
        service_module_name = get_service_module_name(service_module_id)
      end

      modules_path    = OsUtil.service_clone_location()
      module_location = "#{modules_path}/#{service_module_name}#{version && "-#{version}"}"

      reparse_aux(module_location) unless internal_trigger
      push_clone_changes_aux(:service_module,service_module_id,version,nil,internal_trigger)
    end

    desc "delete SERVICE-MODULE-MODULE [-v VERSION] [-y] [-p]", "Delete service module or service module version and all items contained in it. Optional parameter [-p] is to delete local directory."
    version_method_option
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    def delete(context_params)
      module_location, modules_path = nil, nil
      service_module_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      version = options.version
      service_module_name = get_service_module_name(service_module_id)

      unless options.force?
        # Ask user if really want to delete service module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete service-module #{version.nil? ? '' : 'version '}'#{service_module_name}#{version.nil? ? '' : ('-' + version.to_s)}' and all items contained in it"+'?')
      end

      response = 
        if options.purge?
          opts = {:module_name => service_module_name}
          if version then opts.merge!(:version => version)
          else opts.merge!(:delete_all_versions => true)
          end
          
          purge_clone_aux(:service_module,opts)
        else
          Helper(:git_repo).unlink_local_clone?(:service_module,service_module_name,version)
        end
      return response unless response.ok?

      post_body = {
        :service_module_id => service_module_id
      }

      action = (version ? "delete_version" : "delete")
      post_body[:version] = version if version

      response = post rest_url("service_module/#{action}"), post_body
      return response unless response.ok?
      module_name = response.data(:module_name)
      
      # when changing context send request for getting latest services instead of getting from cache
      @@invalidate_map << :service_module

      msg = "Service module '#{service_module_name}' "
      if version then msg << "version #{version} has been deleted"
      else  msg << "has been deleted"; end
      OsUtil.print(msg,:yellow)

      Response::Ok.new()
    end

    desc "delete-from-dtkn REMOTE-SERVICE-MODULE-NAME [-y]", "Delete the service module from the DTK Network catalog"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_from_dtkn(context_params)
      remote_service_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      
      unless options.force?
        # Ask user if really want to delete service module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete remote service-module '#{remote_service_name}' and all items contained in it"+'?')
      end

      post_body = {
       :remote_service_name => remote_service_name,
       :rsa_pub_key => SshProcessing.rsa_pub_key_content()
      }
      response = post rest_url("service_module/delete_remote"), post_body
      @@invalidate_map << :module_service

      return response
    end

    desc "SERVICE-MODULE-NAME/ID delete-assembly ASSEMBLY-TEMPLATE-ID [-y]", "Delete assembly from service module."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_assembly(context_params)
      service_module_id, assembly_template_id = context_params.retrieve_arguments([:service_module_id!,:option_1!], method_argument_names)
      service_module_name = context_params.retrieve_arguments([:service_module_name],method_argument_names)
      assembly_template_name = (assembly_template_id.to_s =~ /^[0-9]+$/) ? DTK::Client::Assembly.get_assembly_template_name_for_service(assembly_template_id, service_module_name) : assembly_template_id
      assembly_template_id   = DTK::Client::Assembly.get_assembly_template_id_for_service(assembly_template_id, service_module_name) unless assembly_template_id.to_s =~ /^[0-9]+$/

      if service_module_name.to_s =~ /^[0-9]+$/
        service_module_id   = service_module_name
        service_module_name = get_service_module_name(service_module_id)
      end

      return unless Console.confirmation_prompt("Are you sure you want to delete assembly '#{assembly_template_name||assembly_template_id}'"+'?') unless options.force?
      
      post_body = {
        :service_module_id => service_module_id,
        :assembly_id => assembly_template_id,
        :subtype => :template                                                                                       
      }

      response = post rest_url("service_module/delete_assembly_template"), post_body
      return response unless response.ok?
      
      modules_path               = OsUtil.service_clone_location()
      module_location            = "#{modules_path}/#{service_module_name}" if service_module_name
      assembly_template_location = "#{module_location}/assemblies/#{assembly_template_name}" if (module_location && assembly_template_name) 
      
      if File.directory?(assembly_template_location)
        unless (assembly_template_location.nil? || ("#{module_location}/assemblies/" == assembly_template_location))
          FileUtils.rm_rf("#{assembly_template_location}")
        end
      end
      version = nil
      commit_msg = "Deleting assembly template #{assembly_template_name.to_s}"
      internal_trigger = true
      push_clone_changes_aux(:service_module, service_module_id, version, commit_msg, internal_trigger)
      @@invalidate_map << :assembly
      Response::Ok.new()
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

