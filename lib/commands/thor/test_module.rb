dtk_require_common_commands('thor/module')
require 'fileutils'

module DTK::Client
  class TestModule < CommandBaseThor

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
      return TestModule.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      get_cached_response(:test_module, "test_module/list", {})
    end

    def self.whoami()
      return :test_module, "test_module/list", nil
    end

    desc "delete TEST-MODULE-NAME [-y] [-p]", "Delete test module and all items contained in it. Optional parameter [-p] is to delete local directory."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    def delete(context_params,method_opts={})
      response = delete_module_aux(context_params, method_opts)
      @@invalidate_map << :test_module if response && response.ok?

      response
    end

    desc "TEST-MODULE-NAME/ID set-attribute ATTRIBUTE-ID VALUE", "Set value of test module attributes"
    def set_attribute(context_params)
      set_attribute_module_aux(context_params)
    end

    desc "list [--remote] [--diff] [-n NAMESPACE]", "List loaded or remote test modules. Use --diff to compare loaded and remote test modules."
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

      response         = post rest_url("test_module/#{action}"),post_body

      return response unless response.ok?
      response.render_table()
    end

    desc "TEST-MODULE-NAME/ID list-components", "List all components for given test module."
    def list_components(context_params)
      module_info_about(context_params, :components, :component)
    end

    desc "TEST-MODULE-NAME/ID list-attributes", "List all attributes for given test module."
    def list_attributes(context_params)
      module_info_about(context_params, :attributes, :attribute_without_link)
    end

    desc "TEST-MODULE-NAME/ID list-instances", "List all instances for given test module."
    def list_instances(context_params)
      module_info_about(context_params, :instances, :component)
    end

    desc "import [NAMESPACE:]TEST-MODULE-NAME", "Create new test module from local clone"
    def import(context_params)
      response = import_module_aux(context_params)
      @@invalidate_map << :test_module

      response
    end

    #
    # Creates component module from input git repo, removing .git dir to rid of pointing to user github, and creates component module
    #
    desc "import-git GIT-SSH-REPO-URL [NAMESPACE:]TEST-MODULE-NAME", "Create new local test module by importing from provided git repo URL"
    def import_git(context_params)
      import_git_module_aux(context_params)
    end

    desc "install NAMESPACE/REMOTE-TEST-MODULE-NAME","Install remote test module into local environment"
    method_option "repo-manager",:aliases => "-r" ,
      :type => :string,
      :banner => "REPO-MANAGER",
      :desc => "DTK Repo Manager from which to resolve requested module."
    def install(context_params)
      response = install_module_aux(context_params)
      @@invalidate_map << :test_module if response && response.ok?

      response
    end

    desc "create [NAMESPACE:]TEST-MODULE-NAME", "Create template test module and generate all needed test module helper files"
    def create(context_params)
      create_test_module_aux(context_params)
    end

    desc "delete-from-catalog NAMESPACE/REMOTE-TEST-MODULE-NAME [-y]", "Delete the test module from the DTK Network catalog"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_from_catalog(context_params)
      delete_from_catalog_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID publish [[NAMESPACE/]REMOTE-TEST-MODULE-NAME]", "Publish test module to remote repository."
    def publish(context_params)
      publish_module_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID pull-dtkn [-n NAMESPACE]", "Update local test module from remote repository."
    method_option "namespace",:aliases => "-n",
      :type => :string,
      :banner => "NAMESPACE",
      :desc => "Remote namespace"
    def pull_dtkn(context_params)
      pull_dtkn_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID chmod PERMISSION-SELECTOR", "Update remote permissions e.g. ug+rw , user and group get RW permissions"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def chmod(context_params)
      chmod_module_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID make-public", "Make this module public"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def make_public(context_params)
      make_public_module_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID make-private", "Make this module private"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def make_private(context_params)
      make_private_module_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID add-collaborators", "Add collabrators users or groups comma seperated (--users or --groups)"
    method_option "namespace", :aliases => "-n", :type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    method_option "users",:aliases => "-u", :type => :string, :banner => "USERS", :desc => "User collabrators"
    method_option "groups",:aliases => "-g", :type => :string, :banner => "GROUPS", :desc => "Group collabrators"
    def add_collaborators(context_params)
      add_collaborators_module_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID remove-collaborators", "Remove collabrators users or groups comma seperated (--users or --groups)"
    method_option "namespace",:aliases => "-n",:type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    method_option "users",:aliases => "-u", :type => :string, :banner => "USERS", :desc => "User collabrators"
    method_option "groups",:aliases => "-g", :type => :string, :banner => "GROUPS", :desc => "Group collabrators"
    def remove_collaborators(context_params)
      remove_collaborators_module_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID list-collaborators", "List collaborators for given module"
    method_option "namespace",:aliases => "-n",:type => :string, :banner => "NAMESPACE", :desc => "Remote namespace"
    def list_collaborators(context_params)
      list_collaborators_module_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID clone [-n]", "Locally clone test module and test files. Use -n to skip edit prompt"
    method_option :skip_edit, :aliases => '-n', :type => :boolean, :default => false
    def clone(context_params, internal_trigger=false)
      clone_module_aux(context_params, internal_trigger)
    end

    desc "TEST-MODULE-NAME/ID edit","Switch to unix editing for given test module."
    def edit(context_params)
      edit_module_aux(context_params)
    end

    desc "TEST-MODULE-NAME/ID push", "Push changes from local copy of test module to server"
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

    desc "TEST-MODULE-NAME/ID push-dtkn [-n NAMESPACE]", "Push changes from local copy of test module to remote repository (dtkn)."
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

    desc "TEST-MODULE-NAME/ID list-diffs", "List diffs"
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
        return unless Console.confirmation_prompt("This will DELETE ALL test modules, are you sure"+'?')
        response = list(context_params)

        response.data().each do |e|
          run_shell_command("delete #{e['display_name']} -y -p")
        end
      end
    end
  end
end