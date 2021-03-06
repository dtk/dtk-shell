#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
dtk_require_common_commands('thor/module')
require 'fileutils'

module DTK::Client
  class ComponentModule < CommandBaseThor

    no_tasks do
      include ModuleMixin
    end

    def self.valid_children()
      [:component, :remotes]
    end

    # this includes children of children - has to be sorted by n-level access
    def self.all_children()
      [:component]
    end

    def self.multi_context_children()
      [[:component], [:remotes], [:component, :remotes]]
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
            :component => [
              ["list","list","# List all component templates."],
              ["list-attributes","list-attributes", "# List all attributes for given component."]
            ],
            :remotes => [
              ["push-remote",  "push-remote [REMOTE-NAME] [--force]",  "# Push local changes to remote git repository"],
              ["list-remotes",  "list-remotes",  "# List git remotes for given module"],
              ["add-remote",    "add-remote REMOTE-NAME REMOTE-URL", "# Add git remote for given module"],
              ["remove-remote", "remove-remote REPO-NAME [-y]", "# Remove git remote for given module"]
            ]
          },
          :identifier_only => {
            :component => [
              ["list-attributes","list-attributes", "# List all attributes for given component."]
            ]
          }

      })
    end

    def self.whoami()
      return :component_module, "component_module/list", nil
    end

    desc "delete-version COMPONENT-MODULE-NAME [-y] [-p] [-v VERSION]", "Delete component module version and all items contained in it. Optional parameter [-p] is to delete local directory."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    version_method_option
    def delete_version(context_params, method_opts = {})
      response = delete_module_aux(context_params, method_opts)
      @@invalidate_map << :component_module if response && response.ok?

      response
    end

    desc "delete COMPONENT-MODULE-NAME [-y] [-p]", "Delete component module and all items contained in it. Optional parameter [-p] is to delete local directory."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    # version_method_option
    def delete(context_params, method_opts = {})
      response = delete_module_aux(context_params, method_opts.merge!(:delete_all => true))
      @@invalidate_map << :component_module if response && response.ok?

      response
    end

    desc "COMPONENT-MODULE-NAME/ID set-attribute ATTRIBUTE-ID VALUE", "Set value of component module attributes"
    def set_attribute(context_params)
      set_attribute_module_aux(context_params)
    end

    desc "list [--remote] [--diffs] [-n NAMESPACE]", "List loaded or remote component modules. Use --diff to compare loaded and remote component modules."
    method_option :remote, :type => :boolean, :default => false
    method_option :diffs, :type => :boolean, :default => false, :aliases => "--diff"
    method_option :namespace, :aliases => "-n" ,
      :type => :string,
      :banner => "NAMESPACE",
      :desc => "List modules only in specific namespace."
    # method_option :with_versions, :type => :boolean, :default => false, :aliases => "with-versions"
    def list(context_params)
      return module_info_about(context_params, :components, :component) if context_params.is_there_command?(:"component")

      forwarded_remote = context_params.get_forwarded_options()["remote"] if context_params.get_forwarded_options()
      remote           = options.remote? || forwarded_remote
      action           = (remote ? "list_remote" : "list")

      post_body        = (remote ? { :rsa_pub_key => SSHUtil.rsa_pub_key_content() } : {:detail_to_include => ["remotes"]})
      post_body[:diff] = options.diffs? ? options.diffs : {}

      if post_body[:detail_to_include]
        post_body[:detail_to_include] << 'versions' # if options.with_versions?
      else
        post_body[:detail_to_include]
      end

      post_body.merge!(:module_namespace => options.namespace) if options.namespace

      response = post rest_url("component_module/#{action}"), post_body

      return response unless response.ok?

      if options.with_versions?
        response.render_table(:module_with_versions, true)
      else
        response.render_table()
      end
    end

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
      module_info_about(context_params, :instances, :component_instances)
    end

    desc "COMPONENT-MODULE-NAME/ID list-versions","List all versions associated with this component module."
    def list_versions(context_params)
      response = list_versions_aux(context_params)
      return response unless response.ok?
      response.render_table(:list_versions, true)
    end

    desc "COMPONENT-MODULE-NAME/ID list-remote-versions","List all remote versions associated with this component module."
    def list_remote_versions(context_params)
      response = list_remote_versions_aux(context_params)
      return response unless response.ok?
      response.render_table(:list_versions, true)
    end

    desc "import [NAMESPACE:]COMPONENT-MODULE-NAME", "Create new component module from local clone"
    def import(context_params)
      response = import_module_aux(context_params)
      @@invalidate_map << :component_module
      response
    end

    desc "import-puppet-forge PUPPET-MODULE-NAME [[NAMESPACE:]COMPONENT-MODULE-NAME]", "Install puppet module from puppet forge"
    def import_puppet_forge(context_params)
      pf_module_name, full_module_name = context_params.retrieve_arguments([:option_1!, :option_2],method_argument_names)
      namespace, module_name = get_namespace_and_name(full_module_name, ModuleUtil::NAMESPACE_SEPERATOR)
      module_type            = get_module_type(context_params)

      OsUtil.print('Retrieving puppet module metadata, please wait ...')
      response = puppet_forge_install_aux(context_params, pf_module_name, module_name, namespace, nil, module_type)

      @@invalidate_map << :component_module
      response
    end

    #
    # Creates component module from input git repo, removing .git dir to rid of pointing to user github, and creates component module
    #
    method_option :branch, :aliases => '-b'
    desc "import-git GIT-SSH-REPO-URL [NAMESPACE:]COMPONENT-MODULE-NAME [-b BRANCH/TAG]", "Create new local component module by importing from provided git repo URL"
    def import_git(context_params)
      response = import_git_module_aux(context_params)
      @@invalidate_map << :component_module
      response
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
    desc "install NAMESPACE/REMOTE-COMPONENT-MODULE-NAME [-v VERSION]","Install remote component module into local environment"
    method_option "repo-manager",:aliases => "-r" ,
      :type => :string,
      :banner => "REPO-MANAGER",
      :desc => "DTK Repo Manager from which to resolve requested module."
      version_method_option
    def install(context_params)
      response = install_module_aux(context_params)
      if response && response.ok?
        @@invalidate_map << :component_module
        # TODO: hack before clean up way to indicate to better format what is passed as hash; these lines print the created module,
        # not the module_directory
        if module_directory = response.data(:module_directory)
          split = module_directory.split('/')
          if split.size > 2
            installed_module = split[split.size-2..split.size-1].join(':')
            response = Response::Ok.new('installed_module' => installed_module)
          end
        end
      end
      response
    end


=begin
    => DUE TO DEPENDENCY TO PUPPET GEM WE OMIT THIS <=
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

      if error = response.data(:dsl_parse_error)
        dsl_parsed_message = ServiceImporter.error_message(module_name, error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red)
      end

      #TODO: need to check if local clone directory exists
      Helper(:git_repo).create_clone_with_branch(:component_module,module_name,repo_url,branch,version)
    end
=end

    desc "delete-from-catalog NAMESPACE/REMOTE-COMPONENT-MODULE-NAME [-y] [--force] [-v VERSION]", "Delete the component module from the DTK Network catalog"
    method_option :confirmed, :aliases => '-y', :type => :boolean, :default => false
    method_option :force, :type => :boolean, :default => false
    version_method_option
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

    desc "COMPONENT-MODULE-NAME/ID publish [[NAMESPACE/]REMOTE-COMPONENT-MODULE-NAME] -v VERSION [--force]", "Publish component module to remote repository."
    version_method_option
    method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    def publish(context_params)
      publish_module_aux(context_params)
    end

    desc "COMPONENT-MODULE-NAME/ID pull-dtkn [-n NAMESPACE] [--force]", "Update local component module from remote repository."
    method_option :namespace,:aliases => '-n',
      :type   => :string,
      :banner => "NAMESPACE",
      :desc   => "Remote namespace"
    method_option :force,:aliases => '-f',
      :type    => :boolean,
      :desc   => "Force pull",
      :default => false
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
    method_option "users", :aliases => "-u", :type => :string, :banner => "USERS", :desc => "User collabrators"
    method_option "groups", :aliases => "-g", :type => :string, :banner => "GROUPS", :desc => "Group collabrators"
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

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method in such way that edit will not be
    #                   triggered after it.
    #
    desc "COMPONENT-MODULE-NAME/ID clone [-n] [-v VERSION]", "Locally clone component module and component files. Use -n to skip edit prompt"
    method_option :skip_edit, :aliases => '-n', :type => :boolean, :default => false
    version_method_option
    def clone(context_params, internal_trigger=true)
      clone_module_aux(context_params, internal_trigger)
    end

#    desc "COMPONENT-MODULE-NAME/ID edit [-v VERSION]","Switch to unix editing for given component module."
    # version_method_option
    desc "COMPONENT-MODULE-NAME/ID edit","Switch to unix editing for given component module."
    def edit(context_params)
      edit_module_aux(context_params)
    end

    desc "COMPONENT-MODULE-NAME/ID push [--force] [--docs]", "Push changes from local copy of component module to server"
    method_option "message",:aliases => "-m" ,
      :type => :string,
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    # hidden option for dev
    method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    method_option :docs, :type => :boolean, :default => false, :aliases => '-d'
    def push(context_params, internal_trigger=false)
      push_module_aux(context_params, internal_trigger)
    end

    # desc "COMPONENT-MODULE-NAME/ID push-dtkn [-n NAMESPACE] [-m COMMIT-MSG]", "Push changes from local copy of component module to remote repository (dtkn)."
    desc "COMPONENT-MODULE-NAME/ID push-dtkn [-n NAMESPACE] [--force]", "Push changes from local copy of component module to remote repository (dtkn)."
    method_option "message",:aliases => "-m" ,
      :type => :string,
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    method_option "namespace",:aliases => "-n",
        :type => :string,
        :banner => "NAMESPACE",
        :desc => "Remote namespace"
    #hidden option for dev
    method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    def push_dtkn(context_params, internal_trigger=false)
      push_dtkn_module_aux(context_params, internal_trigger)
    end
    PushCatalogs = ["origin", "dtkn"]


#    desc "COMPONENT-MODULE-NAME/ID list-diffs [-v VERSION] [--remote]", "List diffs"
    # version_method_option
    desc "COMPONENT-MODULE-NAME/ID list-diffs", "List diffs between module on server and remote repo"
    method_option :remote, :type => :boolean, :default => false
    def list_diffs(context_params)
      list_remote_module_diffs(context_params)
      # list_diffs_module_aux(context_params)
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

    desc "COMPONENT-MODULE-NAME/ID fork NAMESPACE", "Fork component module to new namespace"
    def fork(context_params)
      fork_aux(context_params)
    end

    desc "COMPONENT-MODULE-NAME/ID create-new-version VERSION", "Create new component module version"
    def create_new_version(context_params)
      create_new_version_aux(context_params)
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
