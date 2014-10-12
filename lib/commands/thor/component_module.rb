dtk_require_common_commands('thor/module')
require 'fileutils'

module DTK::Client
  class ComponentModule < CommandBaseThor

    no_tasks do
      include ModuleMixin
    end

    def self.valid_children()
      # [:"component-template"]
      [:component]
    end

    # this includes children of children - has to be sorted by n-level access
    def self.all_children()
      # [:"component-template", :attribute] # Amar: attribute context commented out per Rich suggeston
      # [:"component-template"]
      [:component]
    end

    def self.valid_child?(name_of_sub_context)
      return ComponentModule.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      get_cached_response(:component_module, "component_module/list", {})
    end

    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new(
        {
          :command_only => {
            :self => [
              ["list"," list [--remote] [--diff] [-n NAMESPACE]","# List loaded or remote component modules. Use --diff to compare loaded and remote component modules."]
            ],
            :"component" => [
              ["list","list","# List all component templates."],
              ["list-attributes","list-attributes", "# List all attributes for given component."]
            ]
            #:attribute => [
            #  ['list',"list","List attributes for given component"]
            #]
          },
          :identifier_only => {
            :"component" => [
              ["list-attributes","list-attributes", "# List all attributes for given component."]
            ]
          }

      })
    end

    def self.whoami()
      return :component_module, "component_module/list", nil
    end

#TODO: in for testing; may remove
    # desc "MODULE-NAME/ID test-generate-dsl", "Test generating DSL from implementation"
    # def test_generate_dsl(context_params)
    #   component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
    #   post rest_url("component_module/test_generate_dsl"),{:component_module_id => component_module_id}
    # end

    # desc "MODULE-NAME/ID dsl-upgrade [UPGRADE-VERSION] [-v MODULE-VERSION]","Component module DSL upgrade"
    # version_method_option
    # def dsl_upgrade(context_params)
    #   component_module_id, dsl_version = context_params.retrieve_arguments([:module_id, :option_1],method_argument_names)
    #   dsl_version ||= MostRecentDSLVersion
    #   post_body = {
    #     :component_module_id => component_module_id,
    #     :dsl_version => dsl_version
    #   }
    #   post_body.merge!(:version => options["version"]) if options["version"]
    #    post rest_url("component_module/create_new_dsl_version"),post_body
    # end
    # MostRecentDSLVersion = 2
### end

    #### create and delete commands ###
    # desc "delete COMPONENT-MODULE-NAME [-v VERSION] [-y] [-p]", "Delete component module or component module version and all items contained in it. Optional parameter [-p] is to delete local directory."
    # version_method_option
    desc "delete COMPONENT-MODULE-NAME [-y] [-p]", "Delete component module and all items contained in it. Optional parameter [-p] is to delete local directory."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    def delete(context_params,method_opts={})
      response = delete_module_aux(context_params, method_opts)
      @@invalidate_map << :component_module if response && response.ok?

      response
    end


    desc "COMPONENT-MODULE-NAME/ID set-attribute ATTRIBUTE-ID VALUE", "Set value of component module attributes"
    def set_attribute(context_params)
      set_attribute_module_aux(context_params)
    end

    #### end: create and delete commands ###

=begin
TODO: might deprecate
    #### list and info commands ###
    desc "COMPONENT-MODULE-NAME/ID info", "Get information about given component module."
    def info(context_params)
      component_module_id = context_params.retrieve_arguments([:component_module_id!],method_argument_names)

      post_body = {
        :component_module_id => component_module_id
      }

      response = post rest_url("component_module/info"), post_body
      response.render_custom_info("module")
    end
=end
    desc "list [--remote] [--diff] [-n NAMESPACE]", "List loaded or remote component modules. Use --diff to compare loaded and remote component modules."
    method_option :remote, :type => :boolean, :default => false
    method_option :diff, :type => :boolean, :default => false
    method_option :namespace, :aliases => "-n" ,
      :type => :string,
      :banner => "NAMESPACE",
      :desc => "List modules only in specific namespace."
    def list(context_params)
      return module_info_about(context_params, :components, :component) if context_params.is_there_command?(:"component")

      forwarded_remote = context_params.get_forwarded_options()["remote"] if context_params.get_forwarded_options()
      remote           = options.remote? || forwarded_remote
      action           = (remote ? "list_remote" : "list")

      post_body        = (remote ? { :rsa_pub_key => SSHUtil.rsa_pub_key_content() } : {:detail_to_include => ["remotes"]})
      post_body[:diff] = options.diff? ? options.diff : {}
      post_body.merge!(:module_namespace => options.namespace)

      response = post rest_url("component_module/#{action}"),post_body

      return response unless response.ok?
      response.render_table()
    end

=begin
    desc "COMPONENT-MODULE-NAME/ID list-versions","List all versions associated with this component module."
    def list_versions(context_params)
      component_module_id = context_params.retrieve_arguments([:component_module_id!],method_argument_names)
      post_body = {
        :component_module_id => component_module_id,
        :detail_to_include => ["remotes"],
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }
      response = post rest_url("component_module/versions"), post_body

      response.render_table(:module_version)
    end
=end

    desc "COMPONENT-MODULE-NAME/ID list-components", "List all components for given component module."
    def list_components(context_params)
      module_info_about(context_params, :components, :component)
    end

    desc "COMPONENT-MODULE-NAME/ID list-attributes", "List all attributes for given component module."
    def list_attributes(context_params)
      module_info_about(context_params, :attributes, :attribute_without_link)
    end

    desc "COMPONENT-MODULE-NAME/ID list-instances", "List all instances for given component module."
    def list_instances(context_params)
      module_info_about(context_params, :instances, :component)
    end

    #### end: list and info commands ###

    #### commands to interact with remote repo ###


    desc "import [NAMESPACE:]COMPONENT-MODULE-NAME", "Create new component module from local clone"
    def import(context_params)
      response = import_module_aux(context_params)
      @@invalidate_map << :component_module if (response && response.ok?)

      response
    end

    #
    # Creates component module from input git repo, removing .git dir to rid of pointing to user github, and creates component module
    #
    method_option :branch, :aliases => '-b'
    desc "import-git GIT-SSH-REPO-URL [-b BRANCH/TAG] [NAMESPACE:]COMPONENT-MODULE-NAME", "Create new local component module by importing from provided git repo URL"
    def import_git(context_params)
      import_git_module_aux(context_params)
    end

=begin
#    desc "COMPONENT-MODULE-NAME/ID validate-model [-v VERSION]", "Check the DSL model for errors"
    # version_method_option
    desc "COMPONENT-MODULE-NAME/ID validate-model", "Check the DSL model for errors"
    def validate_model(context_params)
      module_id, module_name = context_params.retrieve_arguments([:component_module_id!, :component_module_name],method_argument_names)
      version = options["version"]

      if module_name.to_s =~ /^[0-9]+$/
        module_id   = module_name
        module_name = get_module_name(module_id)
      end

      modules_path    = OsUtil.component_clone_location()
      module_location = "#{modules_path}/#{module_name}#{version && "-#{version}"}"

      raise DTK::Client::DtkValidationError, "Unable to parse module '#{module_name}#{version && "-#{version}"}' that doesn't exist on your local machine!" unless File.directory?(module_location)

      reparse_aux(module_location)
    end
=end

    # TODO: put in back support for:desc "import REMOTE-MODULE[,...] [LIBRARY-NAME/ID]", "Import remote component module(s) into library"
    # TODO: put in doc REMOTE-MODULE havs namespace and optionally version information; e.g. r8/hdp or r8/hdp/v1.1
    # if multiple items and failire; stops on first failure
#    desc "install [NAMESPACE/]REMOTE-COMPONENT-MODULE-NAME [-r DTK-REPO-MANAGER]","Install remote component module into local environment"
    desc "install NAMESPACE/REMOTE-COMPONENT-MODULE-NAME","Install remote component module into local environment"
    method_option "repo-manager",:aliases => "-r" ,
      :type => :string,
      :banner => "REPO-MANAGER",
      :desc => "DTK Repo Manager from which to resolve requested module."
    def install(context_params)
      response = install_module_aux(context_params)
      @@invalidate_map << :component_module if response && response.ok?

      response
    end


=begin
    => DUE TO DEPENDENCY TO PUPPET GEM WE OMMIT THIS <=
    desc "import-puppet-forge PUPPET-FORGE-MODULE-NAME", "Imports puppet module from puppet forge via puppet gem"
    def import_puppet_forge(context_params)
      module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      # this call will throw exception if error occurs
      module_dir_name = DtkPuppet.install_module(module_name)

      # we change module name to be dir name
      context_params.override_method_argument!(:option_1, module_dir_name)

      # process will take some time adding friendly message
      puts "Cloning to remote repo, please wait ..."

      # rest of reponsabilty is given to import method
      import(context_params)
    end
=end
=begin
    desc "COMPONENT-MODULE-NAME/ID import-version VERSION", "Import a specfic version from a linked component module"
    def import_version(context_params)
      component_module_id,version = context_params.retrieve_arguments([:component_module_id!,:option_1!],method_argument_names)
      post_body = {
        :component_module_id => component_module_id,
        :version => version
      }
      response = post rest_url("component_module/import_version"), post_body
      @@invalidate_map << :component_module

      return response unless response.ok?
      module_name,repo_url,branch,version = response.data(:module_name,:repo_url,:workspace_branch,:version)

      if error = response.data(:dsl_parsed_info)
        dsl_parsed_message = ServiceImporter.error_message(module_name, error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red)
      end

      #TODO: need to check if local clone directory exists
      Helper(:git_repo).create_clone_with_branch(:component_module,module_name,repo_url,branch,version)
    end
=end

    desc "delete-from-catalog NAMESPACE/REMOTE-COMPONENT-MODULE-NAME [-y]", "Delete the component module from the DTK Network catalog"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_from_catalog(context_params)
      delete_from_catalog_aux(context_params)
    end

    # renamed to 'publish' but didn't delete this in case we run into issues with 'publish'
    # desc "COMPONENT-MODULE-NAME/ID create-on-dtkn [[NAMESPACE/]REMOTE-COMPONENT-MODULE-NAME]", "Export component module to remote repository."
    # def create_on_dtkn(context_params)
    #   component_module_id, input_remote_name = context_params.retrieve_arguments([:component_module_id!, :option_1],method_argument_names)

    #   post_body = {
    #     :component_module_id => component_module_id,
    #     :remote_component_name => input_remote_name,
    #     :rsa_pub_key => SSHUtil.rsa_pub_key_content()
    #   }

    #   response = post rest_url("component_module/export"), post_body

    #   return response
    # end

    desc "COMPONENT-MODULE-NAME/ID publish [[NAMESPACE/]REMOTE-COMPONENT-MODULE-NAME]", "Publish component module to remote repository."
    def publish(context_params)
      publish_module_aux(context_params)
    end

    desc "COMPONENT-MODULE-NAME/ID pull-dtkn [-n NAMESPACE]", "Update local component module from remote repository."
    method_option "namespace",:aliases => "-n",
      :type => :string,
      :banner => "NAMESPACE",
      :desc => "Remote namespace"
    def pull_dtkn(context_params)
      pull_dtkn_aux(context_params)
    end


=begin
    desc "COMPONENT-MODULE-NAME/ID chown REMOTE-USER", "Set remote module owner"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def chown(context_params)
      component_module_id, remote_user = context_params.retrieve_arguments([:component_module_id!,:option_1!],method_argument_names)
      chown_aux(component_module_id, remote_user, options.namespace)
    end
=end

    desc "COMPONENT-MODULE-NAME/ID chmod PERMISSION-SELECTOR", "Update remote permissions e.g. ug+rw , user and group get RW permissions"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def chmod(context_params)
      chmod_module_aux(context_params)
    end

    desc "COMPONENT-MODULE-NAME/ID make-public", "Make this module public"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def make_public(context_params)
      make_public_module_aux(context_params)
    end

    desc "COMPONENT-MODULE-NAME/ID make-private", "Make this module private"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def make_private(context_params)
      make_private_module_aux(context_params)
    end

    desc "COMPONENT-MODULE-NAME/ID add-collaborators", "Add collabrators users or groups comma seperated (--users or --groups)"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    method_option "users",:aliases => "-u", :type => :string, :banner => "USERS", :desc => "User collabrators"
    method_option "groups",:aliases => "-g", :type => :string, :banner => "GROUPS", :desc => "Group collabrators"
    def add_collaborators(context_params)
      add_collaborators_module_aux(context_params)
    end

    desc "COMPONENT-MODULE-NAME/ID remove-collaborators", "Remove collabrators users or groups comma seperated (--users or --groups)"
    method_option "namespace",:aliases => "-n",:type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    method_option "users",:aliases => "-u", :type => :string, :banner => "USERS", :desc => "User collabrators"
    method_option "groups",:aliases => "-g", :type => :string, :banner => "GROUPS", :desc => "Group collabrators"
    def remove_collaborators(context_params)
      remove_collaborators_module_aux(context_params)
    end

    desc "COMPONENT-MODULE-NAME/ID list-collaborators", "List collaborators for given module"
    method_option "namespace",:aliases => "-n",:type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def list_collaborators(context_params)
      list_collaborators_module_aux(context_params)
    end


    #### end: commands to interact with remote repo ###

    #### commands to manage workspace and versioning ###
=begin
    desc "COMPONENT-MODULE-NAME/ID create-version VERSION", "Snapshot current state of component module as a new version"
    def create_version(context_params)
      component_module_id,version = context_params.retrieve_arguments([:component_module_id!,:option_1!],method_argument_names)

      post_body = {
        :component_module_id => component_module_id,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }
      response = post rest_url("component_module/versions"), post_body
      return response unless response.ok?
      versions = (response.data.first && response.data.first['versions'])||Array.new
      if versions.include?(version)
        return Response::Error::Usage.new("Version #{version} exists already")
      end

      component_module_name = get_module_name(component_module_id)
      module_location = OsUtil.module_location(:component_module,component_module_name,version)
      if File.directory?(module_location)
        return Response::Error::Usage.new("Target component module directory for version #{version} (#{module_location}) exists already; it must be deleted and this comamnd retried")
      end

      post_body = {
        :component_module_id => component_module_id,
        :version => version
      }
      response = post rest_url("component_module/create_new_version"), post_body
      return response unless response.ok?

      internal_trigger = omit_output = true
      clone_aux(:component_module,component_module_id,version,internal_trigger,omit_output)
    end
=end

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method in such way that edit will not be
    #                   triggered after it.
    #
    #desc "COMPONENT-MODULE-NAME/ID clone [-v VERSION] [-n]", "Locally clone component module and component files. Use -n to skip edit prompt"
    # version_method_option
    desc "COMPONENT-MODULE-NAME/ID clone [-n]", "Locally clone component module and component files. Use -n to skip edit prompt"
    method_option :skip_edit, :aliases => '-n', :type => :boolean, :default => false
    def clone(context_params, internal_trigger=false)
      clone_module_aux(context_params, internal_trigger)
    end

#    desc "COMPONENT-MODULE-NAME/ID edit [-v VERSION]","Switch to unix editing for given component module."
    # version_method_option
    desc "COMPONENT-MODULE-NAME/ID edit","Switch to unix editing for given component module."
    def edit(context_params)
      edit_module_aux(context_params)
    end

#    desc "COMPONENT-MODULE-NAME/ID push [-v VERSION] [-m COMMIT-MSG]", "Push changes from local copy of component module to server"
#    desc "COMPONENT-MODULE-NAME/ID push [-m COMMIT-MSG]", "Push changes from local copy of component module to server"
    desc "COMPONENT-MODULE-NAME/ID push", "Push changes from local copy of component module to server"
     version_method_option
     method_option "message",:aliases => "-m" ,
       :type => :string,
       :banner => "COMMIT-MSG",
       :desc => "Commit message"
     # hidden option for dev
     method_option 'force-parse', :aliases => '-f', :type => :boolean, :default => false
     def push(context_params, internal_trigger=false)
      push_module_aux(context_params, internal_trigger)
     end

#    desc "COMPONENT-MODULE-NAME/ID push-dtkn [-n NAMESPACE] [-m COMMIT-MSG]", "Push changes from local copy of component module to remote repository (dtkn)."
    desc "COMPONENT-MODULE-NAME/ID push-dtkn [-n NAMESPACE]", "Push changes from local copy of component module to remote repository (dtkn)."
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
    def push_dtkn(context_params, internal_trigger=false)
      push_dtkn_module_aux(context_params, internal_trigger)
    end
    PushCatalogs = ["origin", "dtkn"]


#    desc "COMPONENT-MODULE-NAME/ID list-diffs [-v VERSION] [--remote]", "List diffs"
    # version_method_option
    desc "COMPONENT-MODULE-NAME/ID list-diffs [--remote]", "List diffs"
    method_option :remote, :type => :boolean, :default => false
    def list_diffs(context_params)
      list_diffs_module_aux(context_params)
    end

    #
    # DEVELOPMENT MODE METHODS
    #
    if DTK::Configuration.get(:development_mode)

      desc "delete-all","Delete all service modules"
      def delete_all(context_params)
        return unless Console.confirmation_prompt("This will DELETE ALL component modules, are you sure"+'?')
        response = list(context_params)

        response.data().each do |e|
          run_shell_command("delete #{e['display_name']} -y -p")
        end
      end

    end

    #### end: commands related to cloning to and pushing from local clone
  end
end

