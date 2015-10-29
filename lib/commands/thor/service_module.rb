#TODO: putting in version as hidden coption that can be enabled when code ready
#TODO: may be consistent on whether service module id or service module name used as params
dtk_require_common_commands('thor/reparse')
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_from_base("commands/thor/assembly")
dtk_require_from_base('command_helpers/service_importer')
dtk_require_common_commands('thor/common')
dtk_require_common_commands('thor/module')
dtk_require_common_commands('thor/poller')

module DTK::Client
  class ServiceModule < CommandBaseThor

    PULL_CATALOGS = ["dtkn"]

    no_tasks do
      include ReparseMixin
      include ServiceImporter
      include ModuleMixin
      include Poller

      def get_service_module_name(service_module_id)
        get_name_from_id_helper(service_module_id)
      end
    end

    def self.valid_children()
      [:assembly, :remotes]
    end

    def self.all_children()
      [:assembly]
    end

    def self.multi_context_children()
      [[:assembly], [:remotes], [:assembly, :remotes]]
    end

    def self.valid_child?(name_of_sub_context)
      return ServiceModule.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.pretty_print_cols()
      PPColumns.get(:service_module)
    end

    def self.validation_list(context_params)
      get_cached_response(:service_module, "service_module/list", {})
    end

    def self.whoami()
      return :service_module, "service_module/list", nil
    end

    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :command_only => {
          :self => [
            ["list"," list [--remote] [--diff] [-n NAMESPACE]","# List service modules (local/remote). Use --diff to compare loaded and remote modules."]
          ],
          :assembly => [
            ["list","list","# List assemblies for given service module."]
          ],
          :remotes => [
            ["push-remote",   "push-remote [REMOTE-NAME] [--force]",  "# Push local changes to remote git repository"],
            ["list-remotes",  "list-remotes",  "# List git remotes for given module"],
            ["add-remote",    "add-remote REMOTE-NAME REMOTE-URL", "# Add git remote for given module"],
            ["remove-remote", "remove-remote REPO-NAME [-y]", "# Remove git remote for given module"]
          ]
        },
        :identifier_only => {
          :self      => [
            ["list-assemblies","list-assemblies","# List assemblies associated with service module."],
            ["list-modules","list-modules","# List modules associated with service module."]
          ],
          :assembly => [
            ["info","info","# Info for given assembly in current service module."],
            ["stage", "stage [INSTANCE-NAME] [-t TARGET-NAME/ID] [--node-size NODE-SIZE-SPEC] [--os-type OS-TYPE]", "# Stage assembly in target."],
            # ["deploy","deploy [-v VERSION] [INSTANCE-NAME] [-t TARGET-NAME/ID] [-m COMMIT-MSG]", "# Stage and deploy assembly in target."],
            # ["deploy","deploy [INSTANCE-NAME] [-t TARGET-NAME/ID] [-m COMMIT-MSG]", "# Stage and deploy assembly in target."],
            ["deploy","deploy [INSTANCE-NAME] [-m COMMIT-MSG]", "# Stage and deploy assembly in target."],
            ["list-nodes","list-nodes", "# List all nodes for given assembly."],
            ["list-components","list-components", "# List all components for given assembly."],
            ["list-settings","list-settings", "# List all settings for given assembly."]
          ]
        }

      })
    end

    ##MERGE-QUESTION: need to add options of what info is about
    desc "SERVICE-MODULE-NAME/ID info", "Provides information about specified service module"
    def info(context_params)
      module_info_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID list-assemblies","List assemblies associated with service module."
    method_option :remote, :type => :boolean, :default => false
    def list_assemblies(context_params)
      context_params.method_arguments = ["assembly"]
      list(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID list-component-modules","List component modules associated with service module."
    method_option :remote, :type => :boolean, :default => false
    def list_component_modules(context_params)
      context_params.method_arguments = ["modules"]
      list(context_params)
    end

    desc "list [--remote] [--diff] [-n NAMESPACE]","List service modules (local/remote). Use --diff to compare loaded and remote modules."
    method_option :remote, :type => :boolean, :default => false
    method_option :diff, :type => :boolean, :default => false
    method_option :namespace, :aliases => "-n" ,
      :type => :string,
      :banner => "NAMESPACE",
      :desc => "List modules only in specific namespace."
    # method_option :with_versions, :type => :boolean, :default => false, :aliases => "with-versions"
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
        post_body = (options.remote? ? { :rsa_pub_key => SSHUtil.rsa_pub_key_content() } : {:detail_to_include => ["remotes"]})
        post_body[:diff] = options.diff? ? options.diff : {}
        post_body.merge!(:module_namespace => options.namespace) if options.namespace
        post_body[:detail_to_include] << 'versions' if options.with_versions?

        response = post rest_url("service_module/#{action}"), post_body
      # If user is on service identifier level, list task can't have '--remote' option.
      else
        # TODO: this is temp; will shortly support this
        raise DTK::Client::DtkValidationError.new("Not supported '--remote' option when listing service module assemblies, component templates or modules", true) if options.remote?
        raise DTK::Client::DtkValidationError.new("Not supported type '#{about}' for list for current context level. Possible type options: 'assembly'", true) unless(about == "assembly" || about == "modules")

        if about
          case about
          when "assembly"
            data_type        = :assembly_template_description
            action           = "list_assemblies"
          when "modules"
            data_type        = options.remote? ? :component_remote : :component_module
            action           = "list_component_modules"
          else
            raise_validation_error_method_usage('list')
          end
        end
        response = post rest_url("service_module/#{action}"), { :service_module_id => service_module_id }
      end

      unless response.nil?
        if options.with_versions?
          response.render_table(:module_with_versions, true)
        else
          response.render_table(data_type)
        end
      end

      response
    end

    desc "SERVICE-MODULE-NAME/ID list-instances","List all instances associated with this service module."
    def list_instances(context_params)
      list_instances_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID list-versions","List all versions associated with this service module."
    def list_versions(context_params)
      response = list_versions_aux(context_params)
      return response unless response.ok?

      response.render_table(:list_versions, true)
    end

    # version_method_option
    desc "install NAMESPACE/REMOTE-SERVICE-MODULE-NAME [-y] [-v VERSION]", "Install remote service module into local environment. -y will automatically clone component modules."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    # method_option :ignore, :aliases => '-i', :type => :boolean, :default => false
    method_option :update_none, :type => :boolean, :default => false
    version_method_option
    def install(context_params)
      response = install_module_aux(context_params)
      @@invalidate_map << :service_module if response && response.ok?

      response
    end

=begin
    # desc "SERVICE-MODULE-NAME/ID validate-model [-v VERSION]", "Check the DSL Model for Errors"
    # version_method_option
    desc "SERVICE-MODULE-NAME/ID validate-model", "Check the DSL Model for Errors"
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
=end

    # desc "SERVICE-MODULE-NAME/ID import-version VERSION", "Import a specific version from a linked service module"
    # def import_version(context_params)
    #   service_module_id,version = context_params.retrieve_arguments([:service_module_id!,:option_1!],method_argument_names)
    #   post_body = {
    #     :service_module_id => service_module_id,
    #     :version => version
    #   }
    #   response = post rest_url("service_module/import_version"), post_body
    #   @@invalidate_map << :module_service

    #   return response unless response.ok?
    #   module_name,repo_url,branch,version = response.data(:module_name,:repo_url,:workspace_branch,:version)

    #   if error = response.data(:dsl_parse_error)
    #     dsl_parsed_message = ServiceImporter.error_message("#{module_name}-#{version}", error)
    #     DTK::Client::OsUtil.print(dsl_parsed_message, :red)
    #   end

    #   #TODO: need to check if local clone directory exists
    #   Helper(:git_repo).create_clone_with_branch(:service_module,module_name,repo_url,branch,version)
    # end

    # desc "SERVICE-MODULE-NAME/ID create-on-dtkn [[NAMESPACE/]REMOTE-MODULE-NAME]","Export service module to remote repository"
    # def create_on_dtkn(context_params)
    #   service_module_id, input_remote_name = context_params.retrieve_arguments([:service_module_id!, :option_1],method_argument_names)

    #   post_body = {
    #    :service_module_id => service_module_id,
    #    :remote_component_name => input_remote_name,
    #    :rsa_pub_key => SSHUtil.rsa_pub_key_content()
    #   }

    #   post rest_url("service_module/export"), post_body
    # end

    desc "SERVICE-MODULE-NAME/ID publish [[NAMESPACE/]REMOTE-SERVICE-MODULE-NAME]  [-v VERSION] [--force]","Publish service module to remote repository"
    version_method_option
    method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    def publish(context_params)
      publish_module_aux(context_params)
    end

    # desc "SERVICE-MODULE-NAME/ID push-to-dtkn [-n NAMESPACE] [-v VERSION]", "Push local copy of service module to remote repository."
    # version_method_option
    # desc "SERVICE-MODULE-NAME/ID push-to-dtkn [-n NAMESPACE]", "Push local copy of service module to remote repository."
    #     method_option "namespace",:aliases => "-n",
    #     :type => :string,
    #     :banner => "NAMESPACE",
    #     :desc => "Remote namespace"
    # def push_to_dtkn(context_params)
    #   service_module_id, service_module_name = context_params.retrieve_arguments([:service_module_id!, :service_module_name],method_argument_names)
    #   version = options["version"]

    #   if service_module_name.to_s =~ /^[0-9]+$/
    #     service_id   = service_module_name
    #     service_module_name = get_service_module_name(service_id)
    #   end

    #   modules_path    = OsUtil.service_clone_location()
    #   module_location = "#{modules_path}/#{service_module_name}#{version && "-#{version}"}"

    #   unless File.directory?(module_location)
    #     if Console.confirmation_prompt("Unable to push to remote because module '#{service_module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
    #       response = clone_aux(:service_module,service_module_id,version,false)

    #       if(response.nil? || response.ok?)
    #         reparse_aux(module_location)
    #         push_to_remote_aux(:service_module, service_module_id, service_module_name, options["namespace"], version) if Console.confirmation_prompt("Would you like to push changes to remote"+'?')
    #       end

    #       return response
    #     else
    #       # user choose not to clone needed module
    #       return
    #     end
    #   end

    #   reparse_aux(module_location)
    #   push_to_remote_aux(:service_module, service_module_id, service_module_name, options["namespace"], options["version"])
    # end

    # desc "SERVICE-MODULE-NAME/ID pull-from-dtkn [-n NAMESPACE] [-v VERSION]", "Update local service module from remote repository."
    desc "SERVICE-MODULE-NAME/ID update [-n NAMESPACE] [--force]", "Update local service module from remote repository."
    method_option :namespace,:aliases => '-n',
      :type   => :string,
      :banner => "NAMESPACE",
      :desc   => "Remote namespace"
    method_option :force,:aliases => '-f',
      :type    => :boolean,
      :desc   => "Force pull",
      :default => false
    def update(context_params)
      update_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID chmod PERMISSION-SELECTOR", "Update remote permissions e.g. ug+rw , user and group get RW permissions"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def chmod(context_params)
      chmod_module_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID make-public", "Make this module public"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def make_public(context_params)
      make_public_module_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID make-private", "Make this module private"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def make_private(context_params)
      make_private_module_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID add-collaborators", "Add collabrators users or groups comma seperated (--users or --groups)"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    method_option "users",:aliases => "-u", :type => :string, :banner => "USERS", :desc => "User collabrators"
    method_option "groups",:aliases => "-g", :type => :string, :banner => "GROUPS", :desc => "Group collabrators"
    def add_collaborators(context_params)
      add_collaborators_module_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID remove-collaborators", "Remove collabrators users or groups comma seperated (--users or --groups)"
    method_option "namespace",:aliases => "-n",:type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    method_option "users",:aliases => "-u", :type => :string, :banner => "USERS", :desc => "User collabrators"
    method_option "groups",:aliases => "-g", :type => :string, :banner => "GROUPS", :desc => "Group collabrators"
    def remove_collaborators(context_params)
      remove_collaborators_module_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID list-collaborators", "List collaborators for given module"
    method_option "namespace",:aliases => "-n",:type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def list_collaborators(context_params)
      list_collaborators_module_aux(context_params)
    end

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    #
    # desc "SERVICE-MODULE-NAME/ID clone [-v VERSION] [-n]", "Locally clone the service module files. Use -n to skip edit prompt"
    # version_method_option
    desc "SERVICE-MODULE-NAME/ID clone [-n] [-v VERSION]", "Locally clone the service module files. Use -n to skip edit prompt"
    method_option :skip_edit, :aliases => '-n', :type => :boolean, :default => false
    version_method_option
    def clone(context_params, internal_trigger=false)
      clone_module_aux(context_params, internal_trigger)
    end

    # desc "SERVICE-MODULE-NAME/ID edit [-v VERSION]","Switch to unix editing for given service module."
    # version_method_option
    desc "SERVICE-MODULE-NAME/ID edit","Switch to unix editing for given service module."
    def edit(context_params)
      edit_module_aux(context_params)
    end

    # TODO: put in two versions, one that creates empty and anotehr taht creates from local dir; use --empty flag
    desc "import [NAMESPACE:]SERVICE-MODULE-NAME", "Create new service module from local clone"
    def import(context_params)
      module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      namespace, local_module_name = get_namespace_and_name(module_name, ':')

      # first check that there is a directory there and it is not already a git repo, and it ha appropriate content
      response = Helper(:git_repo).check_local_dir_exists_with_content(:service_module, local_module_name, nil, namespace)
      return response unless response.ok?
      service_directory = response.data(:module_directory)

      #check for yaml/json parsing errors before import
      reparse_aux(service_directory)

      # first call to create empty module
      response = post rest_url("service_module/create"), { :module_name => local_module_name, :module_namespace => namespace }
      return response unless response.ok?
      @@invalidate_map << :service_module

      # initial commit for given service module
      service_module_id, repo_info = response.data(:service_module_id, :repo_info)
      repo_url,repo_id,module_id,branch,new_module_name = [:repo_url,:repo_id,:module_id,:workspace_branch,:full_module_name].map { |k| repo_info[k.to_s] }

      response = Helper(:git_repo).rename_and_initialize_clone_and_push(:service_module, local_module_name, new_module_name,branch,repo_url,service_directory)
      return response unless (response && response.ok?)

      repo_obj,commit_sha = response.data(:repo_obj,:commit_sha)
      module_final_dir = repo_obj.repo_dir
      old_dir = response.data[:old_dir]

      context_params.add_context_to_params(local_module_name, :"service-module", module_id)
      response = push(context_params,true)

      unless response.ok?
        # remove new directory and leave the old one if import without namespace failed
        if old_dir and (old_dir != module_final_dir)
          FileUtils.rm_rf(module_final_dir) unless namespace
        end
        return response
      end

      # remove the old one if no errors while importing
      # DTK-1768: removed below; and replaced by removing old dir if unequal to final dir
      # was not sure why clause namespace  was in so kept this condition
      #FileUtils.rm_rf(old_dir) unless namespace
      if old_dir and (old_dir != module_final_dir)
        FileUtils.rm_rf(old_dir) unless namespace
      end
      DTK::Client::OsUtil.print("Module '#{new_module_name}' has been created and module directory moved to #{repo_obj.repo_dir}",:yellow) unless namespace

      response
    end


    # desc "SERVICE-MODULE-NAME/ID push [-v VERSION] [-m COMMIT-MSG]", "Push changes from local copy of service module to server"
    # version_method_option
=begin
    desc "SERVICE-MODULE-NAME/ID push origin|dtkn [-n NAMESPACE] [-m COMMIT-MSG]", "Push changes from local copy of service module to server (origin) or to remote repository (dtkn)."
    method_option "message",:aliases => "-m" ,
      :type => :string,
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    method_option "namespace",:aliases => "-n",
        :type => :string,
        :banner => "NAMESPACE",
        :desc => "Remote namespace"
    #hidden option for dev
    method_option 'force-parse', :aliases => '-f', :type => :boolean, :default => false
    def push(context_params, internal_trigger=false)
      service_module_id, service_module_name, catalog = context_params.retrieve_arguments([:service_module_id!, :service_module_name, :option_1],method_argument_names)
      version = options["version"]

      raise DtkValidationError, "You have to provide valid catalog to push changes to! Valid catalogs: #{PushCatalogs}" unless catalog

      if service_module_name.to_s =~ /^[0-9]+$/
        service_module_id   = service_module_name
        service_module_name = get_service_module_name(service_module_id)
      end

      modules_path    = OsUtil.service_clone_location()
      module_location = "#{modules_path}/#{service_module_name}#{version && "-#{version}"}"
      reparse_aux(module_location) unless internal_trigger

      if catalog.to_s.eql?("origin")
        push_clone_changes_aux(:service_module,service_module_id,version,nil,internal_trigger)
      elsif catalog.to_s.eql?("dtkn")
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

      push_to_remote_aux(:service_module, service_module_id, service_module_name, options["namespace"], options["version"])
      else
        raise DtkValidationError, "You have to provide valid catalog to push changes to! Valid catalogs: #{PushCatalogs}"
      end
    end
    PushCatalogs = ["origin", "dtkn"]
=end

#    desc "SERVICE-MODULE-NAME/ID push [-m COMMIT-MSG]", "Push changes from local copy to server (origin)."
    desc "SERVICE-MODULE-NAME/ID push [--force] [--docs]", "Push changes from local copy to server."
    method_option "message",:aliases => "-m" ,
      :type => :string,
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    method_option :docs, :type => :boolean, :default => false, :aliases => '-d'
    def push(context_params, internal_trigger=false)
      push_module_aux(context_params, internal_trigger)
    end

#    desc "SERVICE-MODULE-NAME/ID push-dtkn [-n NAMESPACE] [-m COMMIT-MSG]", "Push changes from local copy of service module to remote repository (dtkn)."
    # desc "SERVICE-MODULE-NAME/ID push-dtkn [-n NAMESPACE] [--force]", "Push changes from local copy of service module to remote repository (dtkn)."
    # method_option "message",:aliases => "-m" ,
    #   :type => :string,
    #   :banner => "COMMIT-MSG",
    #   :desc => "Commit message"
    # method_option "namespace",:aliases => "-n",
    #     :type => :string,
    #     :banner => "NAMESPACE",
    #     :desc => "Remote namespace"
    # method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    # def push_dtkn(context_params, internal_trigger=false)
    #   push_dtkn_module_aux(context_params, internal_trigger)
    # end

    desc "SERVICE-MODULE-NAME/ID list-diffs", "List diffs between module on server and remote repo"
    method_option :remote, :type => :boolean, :default => false
    def list_diffs(context_params)
      list_remote_module_diffs(context_params)
      # list_diffs_module_aux(context_params)
    end

    # desc "delete SERVICE-MODULE-NAME [-v VERSION] [-y] [-p]", "Delete service module or service module version and all items contained in it. Optional parameter [-p] is to delete local directory."
    # version_method_option
    desc "delete SERVICE-MODULE-NAME [-y] [-p] [-v VERSION]", "Delete service module and all items contained in it. Optional parameter [-p] is to delete local directory."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    version_method_option
    def delete(context_params)
      response = delete_module_aux(context_params)
      @@invalidate_map << :service_module if response && response.ok?

      response
    end

    desc "delete-from-catalog NAMESPACE/REMOTE-SERVICE-MODULE-NAME [-y] [--force] [-v VERSION]", "Delete the service module from the DTK Network catalog"
    method_option :confirmed, :aliases => '-y', :type => :boolean, :default => false
    method_option :force, :type => :boolean, :default => false
    version_method_option
    def delete_from_catalog(context_params)
      delete_from_catalog_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID delete-assembly ASSEMBLY-NAME [-y]", "Delete assembly from service module."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_assembly(context_params)
      response = delete_assembly_aux(context_params)
      @@invalidate_map << :assembly if response && response.ok?

      response
    end


    # REMOTE INTERACTION

    desc "HIDE_FROM_BASE push-remote [REMOTE-NAME] [--force]", "Push local changes to remote git repository"
    method_option :force, :type => :boolean, :default => false
    def push_remote(context_params)
      push_remote_module_aux(context_params)
    end

    desc "HIDE_FROM_BASE list-remotes", "List git remotes for given module"
    def list_remotes(context_params)
      remote_list_aux(context_params)
    end

    desc "HIDE_FROM_BASE add-remote REMOTE-NAME REMOTE-URL", "Add git remote for given module"
    def add_remote(context_params)
      remote_add_aux(context_params)
    end

    desc "HIDE_FROM_BASE remove-remote REPO-NAME [-y]", "Remove git remote for given module"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def remove_remote(context_params)
      remote_remove_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID fork NAMESPACE", "Fork service module to new namespace"
    def fork(context_params)
      fork_aux(context_params)
    end

    desc "SERVICE-MODULE-NAME/ID create-new-version VERSION", "Create new service module version"
    def create_new_version(context_params)
      create_new_version_aux(context_params)
    end

    #
    # DEVELOPMENT MODE METHODS
    #
    if DTK::Configuration.get(:development_mode)

      desc "delete-all","Delete all service modules"
      def delete_all(context_params)
        return unless Console.confirmation_prompt("This will DELETE ALL service modules, are you sure"+'?')
        response = list(context_params)

        response.data().each do |e|
          run_shell_command("delete #{e['display_name']} -y -p")
        end
      end

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

