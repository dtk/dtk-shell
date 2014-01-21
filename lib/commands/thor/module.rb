dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_dtk_common('grit_adapter')
dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/list_diffs')
dtk_require_common_commands('thor/push_to_remote')
dtk_require_common_commands('thor/pull_from_remote')
dtk_require_common_commands('thor/push_clone_changes')
dtk_require_common_commands('thor/edit')
dtk_require_common_commands('thor/reparse')
dtk_require_common_commands('thor/purge_clone')
dtk_require_from_base('configurator')
dtk_require_from_base('command_helpers/service_importer')

require 'fileutils'

module DTK::Client
  class Module < CommandBaseThor

    DEFAULT_COMMIT_MSG = "Initial commit."

    def self.valid_children()
      [:"component-template"]
    end

    # this includes children of children - has to be sorted by n-level access
    def self.all_children()
      # [:"component-template", :attribute] # Amar: attribute context commented out per Rich suggeston
      [:"component-template"]
    end

    def self.valid_child?(name_of_sub_context)
      return Module.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      get_cached_response(:module_component, "component_module/list", {})
    end

     def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new(
        {
          :command_only => {
            :self => [
              ["list"," list [--remote] [--diff]","# List loaded or remote component modules. Use --diff to compare loaded and remote modules."]
            ],
            :"component-template" => [
              ["list","list","# List all component templates."],
              ["list-attributes","list-attributes", "# List all attributes for given component module."]
            ]            
            #:attribute => [
            #  ['list',"list","List attributes for given component"]
            #]
          },
          :identifier_only => {
            :"component-template" => [
              ["list-attributes","list-attributes", "# List all attributes for given component template."]
            ]
          }

      })
    end

    no_tasks do
      include CloneMixin
      include PushToRemoteMixin
      include PullFromRemoteMixin
      include PushCloneChangesMixin
      include EditMixin
      include ReparseMixin
      include PurgeCloneMixin
      include ListDiffsMixin
      include ServiceImporter

      def get_module_name(module_id)
        get_name_from_id_helper(module_id)
      end

      def module_info_about(context_params, about, data_type)
        component_module_id, component_template_id = context_params.retrieve_arguments([:module_id!, :component_template_id],method_argument_names)
        post_body = {
          :component_module_id => component_module_id,
          :component_template_id => component_template_id,
          :about => about
        }
        response = post rest_url("component_module/info_about"), post_body
        data_type = data_type
        response.render_table(data_type) unless options.list?
      end
    end

    def self.whoami()
      return :module_component, "component_module/list", nil
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
    desc "delete MODULE [-v VERSION] [-y] [-p]", "Delete component module or component module version and all items contained in it. Optional parameter [-p] is to delete local directory."
    version_method_option
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    def delete(context_params,method_opts={})
      module_location, modules_path = nil, nil
      component_module_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      version = options.version
      component_module_name = get_module_name(component_module_id)

      unless (options.force? || method_opts[:force_delete])
        # Ask user if really want to delete component module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete component-module #{version.nil? ? '' : 'version '}'#{component_module_name}#{version.nil? ? '' : ('-' + version.to_s)}' and all items contained in it"+'?')
      end

      response = 
        if options.purge?
          opts = {:module_name => component_module_name}
          if version then opts.merge!(:version => version)
          else opts.merge!(:delete_all_versions => true)
          end
          purge_clone_aux(:component_module,opts)
        else
          Helper(:git_repo).unlink_local_clone?(:component_module,component_module_name,version)
        end
      return response unless response.ok?

      post_body = {
       :component_module_id => component_module_id
      }
      action = (version ? "delete_version" : "delete")
      post_body[:version] = version if version
      
      response = post(rest_url("component_module/#{action}"), post_body)
      return response unless response.ok?
      
      # when changing context send request for getting latest modules instead of getting from cache
      @@invalidate_map << :module_component

      unless method_opts[:no_error_msg]
        msg = "Component module '#{component_module_name}' "
        if version then msg << "version #{version} has been deleted"
        else  msg << "has been deleted"; end
        OsUtil.print(msg,:yellow)
      end
      Response::Ok.new()
    end


    desc "MODULE-NAME/ID set-attribute ATTRIBUTE-ID VALUE", "Set value of module attributes"
    def set_attribute(context_params)
      if context_params.is_there_identifier?(:attribute)
        mapping = [:module_id!,:attribute_id!, :option_1]
      else
        mapping = [:module_id!,:option_1!,:option_2]
      end

      module_component_id, attribute_id, value = context_params.retrieve_arguments(mapping,method_argument_names)

      post_body = {
        :attribute_id => attribute_id,
        :attribute_value => value
      }
      
      post rest_url("attribute/set"), post_body
    end

    #### end: create and delete commands ###

    #### list and info commands ###
    desc "MODULE-NAME/ID info", "Get information about given component module."
    def info(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      
      post_body = {
        :component_module_id => component_module_id
      }

      response = post rest_url("component_module/info"), post_body
      response.render_custom_info("module")
    end

    desc "list [--remote] [--diff]", "List loaded or remote component modules. Use --diff to compare loaded and remote modules."
    method_option :remote, :type => :boolean, :default => false
    method_option :diff, :type => :boolean, :default => false
    def list(context_params)
      # Amar: attribute context commented out per Rich suggeston
      #if context_params.is_there_command?(:attribute)
      #  return module_info_about(context_params, :attributes, :attribute)
      #elsif context_params.is_there_command?(:"component-template")
      if context_params.is_there_command?(:"component-template")
        return module_info_about(context_params, :components, :component)
      end

      action           = (options.remote? ? "list_remote" : "list")
      post_body        = (options.remote? ? { :rsa_pub_key => SshProcessing.rsa_pub_key_content() } : {:detail_to_include => ["remotes","versions"]})
      post_body[:diff] = options.diff? ? options.diff : {}
      response         = post rest_url("component_module/#{action}"),post_body
      
      return response unless response.ok?
      response.render_table()
    end


    desc "MODULE-NAME/ID list-versions","List all versions associated with this module."
    def list_versions(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      post_body = {
        :component_module_id => component_module_id,
        :detail_to_include => ["remotes"],
        :rsa_pub_key => SshProcessing.rsa_pub_key_content()
      }
      response = post rest_url("component_module/versions"), post_body

      response.render_table(:module_version)
    end

    desc "MODULE-NAME/ID list-components", "List all components for given component module."
    def list_components(context_params)
      module_info_about(context_params, :components, :component)
    end

    desc "MODULE-NAME/ID list-attributes", "List all attributes for given component module."
    def list_attributes(context_params)
      module_info_about(context_params, :attributes, :attribute_without_link)
    end

    desc "MODULE-NAME/ID list-instances", "List all instances for given component module."
    def list_instances(context_params)
      module_info_about(context_params, :instances, :component)
    end

    #### end: list and info commands ###

    #### commands to interact with remote repo ###


    desc "import MODULE-NAME", "Create new module from local clone"
    def import(context_params)
      git_import = context_params.get_forwarded_options()[:git_import] if context_params.get_forwarded_options()
      name_option = git_import ? :option_2! : :option_1!
      module_name = context_params.retrieve_arguments([name_option],method_argument_names)
      
      # first check that there is a directory there and it is not already a git repo, and it ha appropriate content
      response = Helper(:git_repo).check_local_dir_exists_with_content(:component_module,module_name)
      return response unless response.ok?
      module_directory = response.data(:module_directory)

      # first make call to server to create an empty repo
      response = post rest_url("component_module/create"), { :module_name => module_name }
      return response unless response.ok?
      @@invalidate_map << :module_component

      repo_url,repo_id,module_id,branch = response.data(:repo_url,:repo_id,:module_id,:workspace_branch)
      response = Helper(:git_repo).initialize_client_clone_and_push(:component_module,module_name,branch,repo_url)
      return response unless response.ok?
      repo_obj,commit_sha =  response.data(:repo_obj,:commit_sha)

      post_body = {
        :repo_id => repo_id,
        :component_module_id => module_id,
        :commit_sha => commit_sha,
        :scaffold_if_no_dsl => true
      }
      response = post(rest_url("component_module/update_from_initial_create"),post_body)
      return response unless response.ok?

      external_dependencies = response.data(:external_dependencies)

      if error = response.data(:dsl_parsed_info)
        dsl_parsed_message = ServiceImporter.error_message(module_name, error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red) 
      end

      dsl_created_info = response.data(:dsl_created_info)
      if dsl_created_info and !dsl_created_info.empty?
        msg = "A #{dsl_created_info["path"]} file has been created for you, located at #{module_directory}"
        response = Helper(:git_repo).add_file(repo_obj,dsl_created_info["path"],dsl_created_info["content"],msg)
      else
        response = Response::Ok.new("module_created" => module_name)
      end

      # we push clone changes anyway, user can change and push again
      context_params.add_context_to_params(module_name, "module", module_id)
      response = push(context_params, true)
      response[:module_id] = module_id if git_import
      response.add_data_value!(:external_dependencies,external_dependencies) if external_dependencies

      return response
    end

    desc "MODULE-NAME/ID validate-model [-v VERSION]", "Check the DSL model for errors"
    version_method_option
    def validate_model(context_params)
      module_id, module_name = context_params.retrieve_arguments([:module_id!, :module_name],method_argument_names)
      version = options["version"]

      if module_name.to_s =~ /^[0-9]+$/
        module_id   = module_name
        module_name = get_module_name(module_id)
      end

      modules_path    = OsUtil.module_clone_location()
      module_location = "#{modules_path}/#{module_name}#{version && "-#{version}"}"

      raise DTK::Client::DtkValidationError, "Unable to parse module '#{module_name}#{version && "-#{version}"}' that doesn't exist on your local machine!" unless File.directory?(module_location)

      reparse_aux(module_location)
    end
    
    # TODO: put in back support for:desc "import REMOTE-MODULE[,...] [LIBRARY-NAME/ID]", "Import remote component module(s) into library"
    # TODO: put in doc REMOTE-MODULE havs namespace and optionally version information; e.g. r8/hdp or r8/hdp/v1.1
    # if multiple items and failire; stops on first failure
    desc "import-dtkn NAMESPACE/REMOTE-MODULE-NAME [-r DTK-REPO-MANAGER]","Import remote component module into local environment"
    method_option "repo-manager",:aliases => "-r" ,
      :type => :string, 
      :banner => "REPO-MANAGER",
      :desc => "DTK Repo Manager from which to resolve requested module."
    def import_dtkn(context_params)
      create_missing_clone_dirs()
      check_direct_access(::DTK::Client::Configurator.check_direct_access)
      remote_module_name, version = context_params.retrieve_arguments([:option_1!, :option_2],method_argument_names)
      # in case of auto-import via service import, we skip cloning to speed up a process
      skip_cloning = context_params.get_forwarded_options()['skip_cloning'] if context_params.get_forwarded_options()
      do_not_raise = context_params.get_forwarded_options()[:do_not_raise] if context_params.get_forwarded_options()
      ignore_component_error = context_params.get_forwarded_options()[:ignore_component_error] if context_params.get_forwarded_options()
      additional_message = context_params.get_forwarded_options()[:additional_message] if context_params.get_forwarded_options()
      
      remote_namespace, local_module_name = get_namespace_and_name(remote_module_name)
      if clone_dir = Helper(:git_repo).local_clone_dir_exists?(:component_module,local_module_name,version)
        message = "Module's directory (#{clone_dir}) exists on client. To import this needs to be renamed or removed"
        message += ". To ignore this conflict and use existing module please use -i switch (import-dtkn REMOTE-SERVICE-NAME -i)." if additional_message

        raise DtkError, message unless ignore_component_error
      end
      post_body = {
        :remote_module_name => remote_module_name,
        :local_module_name => local_module_name,
        :rsa_pub_key => SshProcessing.rsa_pub_key_content()
      }
      post_body.merge!(:do_not_raise => do_not_raise) if do_not_raise
      post_body.merge!(:ignore_component_error => ignore_component_error) if ignore_component_error
      post_body.merge!(:additional_message => additional_message) if additional_message
      
      response = post rest_url("component_module/import"), post_body
      return response unless response.ok?

      return response if response.data(:does_not_exist)      
      module_name,repo_url,branch,version = response.data(:module_name,:repo_url,:workspace_branch,:version)
      
      if error = response.data(:dsl_parsed_info)
        dsl_parsed_message = ServiceImporter.error_message(module_name, error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red) 
      end

      response = ""
      unless skip_cloning
        response = Helper(:git_repo).create_clone_with_branch(:component_module,module_name,repo_url,branch,version)
      end
      @@invalidate_map << :module_component

      response
    end

    #
    # Creates component module from input git repo, removing .git dir to rid of pointing to user github, and creates component module
    #
    desc "import-git GIT-SSH-REPO-URL MODULE-NAME", "Create new local module by importing from provided git repo URL"
    def import_git(context_params)
      git_repo_url, module_name = context_params.retrieve_arguments([:option_1!, :option_2!],method_argument_names)
      
      # Create component module from user's input git repo
      response = Helper(:git_repo).create_clone_with_branch(:component_module, module_name, git_repo_url)
      
      # Raise error if git repository is invalid
      # raise DtkError,"Git repository URL '#{git_repo_url}' is invalid." unless response.ok?
      return response unless response.ok?

      # Remove .git directory to rid of git pointing to user's github
      FileUtils.rm_rf("#{response['data']['module_directory']}/.git")
      
      context_params.forward_options({:git_import => true})
      # Reuse module create method to create module from local component_module
      create_response = import(context_params)
      
      if create_response.ok?
        if external_dependencies = create_response.data(:external_dependencies)
          inconsistent = external_dependencies["inconsistent"]
          possibly_missing = external_dependencies["possibly_missing"]
          OsUtil.print("There are some inconsistent dependencies: #{inconsistent}", :red) unless inconsistent.empty?
          OsUtil.print("There are some missing dependencies: #{possibly_missing}", :yellow) unless possibly_missing.empty?
        end
      else
        # If server response is not ok, delete cloned module, invoke delete method
        FileUtils.rm_rf("#{response['data']['module_directory']}")
        delete(context_params,:force_delete => true, :no_error_msg => true)
        return create_response
      end
      
      Response::Ok.new()
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

    desc "MODULE-NAME/ID import-version VERSION", "Import a specfic version from a linked component module"
    def import_version(context_params)
      component_module_id,version = context_params.retrieve_arguments([:module_id!,:option_1!],method_argument_names)
      post_body = {
        :component_module_id => component_module_id,
        :version => version
      }
      response = post rest_url("component_module/import_version"), post_body
      @@invalidate_map << :module_component

      return response unless response.ok?
      module_name,repo_url,branch,version = response.data(:module_name,:repo_url,:workspace_branch,:version)

      if error = response.data(:dsl_parsed_info)
        dsl_parsed_message = ServiceImporter.error_message(module_name, error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red) 
      end

      #TODO: need to check if local clone directory exists
      Helper(:git_repo).create_clone_with_branch(:component_module,module_name,repo_url,branch,version)
    end
    
    desc "delete-from-dtkn [NAME-SPACE/]REMOTE-MODULE [-y]", "Delete the component module from the DTK Network catalog"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_from_dtkn(context_params)
      remote_module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      remote_namespace, remote_name = get_namespace_and_name(remote_module_name)

      unless options.force?
        # Ask user if really want to delete component module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete remote component-module '#{remote_namespace.nil? ? '' : remote_namespace+'/'}#{remote_name}' and all items contained in it"+'?')
      end

      post_body = {
       :remote_module_name      => remote_name,
       :remote_module_namespace => remote_namespace,
       :rsa_pub_key => SshProcessing.rsa_pub_key_content()
      }
      post rest_url("component_module/delete_remote"), post_body
    end

    desc "MODULE-NAME/ID create-on-dtkn [[NAME-SPACE/]REMOTE-MODULE-NAME]", "Export component module to remote repository."
    def create_on_dtkn(context_params)
      component_module_id, input_remote_name = context_params.retrieve_arguments([:module_id!, :option_1],method_argument_names)

      post_body = {
        :component_module_id => component_module_id,
        :remote_component_name => input_remote_name,
        :rsa_pub_key => SshProcessing.rsa_pub_key_content()
      }

      response = post rest_url("component_module/export"), post_body
      
      return response         
    end

    desc "MODULE-NAME/ID push-to-dtkn [-n NAMESPACE] [-v VERSION]", "Push local copy of component module to remote repository."
    version_method_option
    method_option "namespace",:aliases => "-n",
        :type => :string, 
        :banner => "NAMESPACE",
        :desc => "Remote namespace"
    def push_to_dtkn(context_params)
      component_module_id, component_module_name = context_params.retrieve_arguments([:module_id!, :module_name!],method_argument_names)
      version = options["version"]

      if component_module_name.to_s =~ /^[0-9]+$/
        component_module_id   = component_module_name
        component_module_name = get_module_name(component_module_id)
      end

      modules_path    = OsUtil.module_clone_location()
      module_location = "#{modules_path}/#{component_module_name}#{version && "-#{version}"}"

      unless File.directory?(module_location)
        if Console.confirmation_prompt("Unable to push to remote because module '#{component_module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          response = clone_aux(:component_module,component_module_id,version,false)
          
          if(response.nil? || response.ok?)
            reparse_aux(module_location)
            push_to_remote_aux(:component_module, component_module_id, component_module_name, options["namespace"], version)  if Console.confirmation_prompt("Would you like to push changes to remote"+'?')
          end

          return response
        else
          # user choose not to clone needed module
          return
        end
      end

      reparse_aux(module_location)
      push_to_remote_aux(:component_module, component_module_id, component_module_name, options["namespace"], version)
    end

    desc "MODULE-NAME/ID pull-from-dtkn [-v VERSION]", "Update local component module from remote repository."
    version_method_option
    def pull_from_dtkn(context_params)     
      component_module_id, component_module_name = context_params.retrieve_arguments([:module_id!,:module_name],method_argument_names)
      version = options["version"]

      response = pull_from_remote_aux(:component_module,component_module_id,version)
      return response unless response.ok?

      if component_module_name.to_s =~ /^[0-9]+$/
        component_module_id = component_module_name
        component_module_name = get_module_name(component_module_id)
      end

      modules_path    = OsUtil.module_clone_location()
      module_location = "#{modules_path}/#{component_module_name}#{version && "-#{version}"}"

      push_clone_changes_aux(:component_module,component_module_id,version,nil,true) if File.directory?(module_location)
      Response::Ok.new()
    end

    #### end: commands to interact with remote repo ###

    #### commands to manage workspace and versioning ###
    desc "MODULE-NAME/ID create-version VERSION", "Snapshot current state of module as a new version"
    def create_version(context_params)
      component_module_id,version = context_params.retrieve_arguments([:module_id!,:option_1!],method_argument_names)

      post_body = {
        :component_module_id => component_module_id,
        :rsa_pub_key => SshProcessing.rsa_pub_key_content()
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

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method in such way that edit will not be 
    #                   triggered after it.
    #
    desc "MODULE-NAME/ID clone [-v VERSION] [-n]", "Locally clone module and component files. Use -n to skip edit prompt"
    method_option :skip_edit, :aliases => '-n', :type => :boolean, :default => false
    version_method_option
    def clone(context_params, internal_trigger=false)
      thor_options = context_params.get_forwarded_options() || options
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      module_name         = context_params.retrieve_arguments([:module_name],method_argument_names)
      version             = thor_options["version"]
      internal_trigger    = true if thor_options['skip_edit']   

      # if this is not name it will not work, we need module name
      if module_name.to_s =~ /^[0-9]+$/
        component_module_id   = module_name
        module_name = get_module_name(component_module_id)
      end

      modules_path    = OsUtil.module_clone_location()
      module_location = "#{modules_path}/#{module_name}#{version && "-#{version}"}"

      raise DTK::Client::DtkValidationError, "Trying to clone a module '#{module_name}#{version && "-#{version}"}' that exists already!" if File.directory?(module_location)
      clone_aux(:component_module,component_module_id,version,internal_trigger,thor_options['omit_output'])
    end

    desc "MODULE-NAME/ID edit [-v VERSION]","Switch to unix editing for given module."
    version_method_option
    def edit(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      module_name         = context_params.retrieve_arguments([:module_name],method_argument_names)
      version             = options.version||context_params.retrieve_arguments([:option_1],method_argument_names)
      edit_dsl            = context_params.get_forwarded_options()[:edit_dsl] if context_params.get_forwarded_options()

      # if this is not name it will not work, we need module name
      if module_name.to_s =~ /^[0-9]+$/
        component_module_id   = module_name
        module_name = get_module_name(component_module_id)
      end

      #TODO: cleanup so dont need :base_file_name and get edit_file from server
      opts = {}
      base_file_name = "dtk.model"
      opts.merge!(:edit_file => {:base_file_name => base_file_name}) if edit_dsl
      edit_aux(:component_module,component_module_id,module_name,version,opts)
    end

    desc "MODULE-NAME/ID push [-v VERSION] [-m COMMIT-MSG]", "Push changes from local copy of module to server"
    version_method_option
    method_option "message",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    #hidden options for dev
    method_option 'parse', :aliases => '-p', :type => :boolean, :default => false
    def push(context_params, internal_trigger=false)
      component_module_id, component_module_name = context_params.retrieve_arguments([:module_id!, :module_name],method_argument_names)
      version = options["version"]
      if component_module_name.to_s =~ /^[0-9]+$/
        component_module_id   = component_module_name
        component_module_name = get_module_name(component_module_id)
      end

      modules_path    = OsUtil.module_clone_location()
      module_location = "#{modules_path}/#{component_module_name}#{version && "-#{version}"}"

      reparse_aux(module_location)
      push_clone_changes_aux(:component_module,component_module_id,version,options["message"]||DEFAULT_COMMIT_MSG,internal_trigger)
    end

    desc "MODULE-NAME/ID list-diffs [-v VERSION] [--remote]", "List diffs"
    version_method_option
    method_option :remote, :type => :boolean, :default => false
    def list_diffs(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      module_name         = context_params.retrieve_arguments([:module_name],method_argument_names)
      version             = options["version"]

      # if this is not name it will not work, we need module name
      if module_name.to_s =~ /^[0-9]+$/
        component_module_id   = module_name
        module_name = get_module_name(component_module_id)
      end

      modules_path    = OsUtil.module_clone_location()
      module_location = "#{modules_path}/#{module_name}#{version && "-#{version}"}"

      # check if there is repository cloned 
      if File.directory?(module_location)
        list_diffs_aux(:component_module, component_module_id, options.remote?, version)
      else
        if Console.confirmation_prompt("Module '#{module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          response = clone_aux(:component_module,component_module_id,version,true)
          # if error return
          unless response.ok?
            return response
          end
        else
          # user choose not to clone needed module
          return
        end
      end

    end

    #### end: commands related to cloning to and pushing from local clone
  end
end

