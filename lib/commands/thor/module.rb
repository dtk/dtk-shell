dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_dtk_common('grit_adapter')
dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/list_diffs')
dtk_require_common_commands('thor/push_to_remote')
dtk_require_common_commands('thor/pull_from_remote')
dtk_require_common_commands('thor/push_clone_changes')
dtk_require_common_commands('thor/edit')
dtk_require_common_commands('thor/reparse')
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
      include ListDiffsMixin
      include ServiceImporter

      def get_module_name(module_id)
        module_name = nil
        # TODO: See with Rich if there is better way to resolve this
        response = DTK::Client::CommandBaseThor.get_cached_response(:module, "component_module/list")

        if response.ok?
          unless response['data'].nil?
            response['data'].each do |module_item|
              if module_id.to_i == (module_item['id'])
                module_name = module_item['display_name']
                break
              end
            end
          end
        end

        raise DTK::Client::DtkError, "Not able to resolve module name, please provide module name." if module_name.nil?
        return module_name
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
    desc "MODULE-NAME/ID test-generate-dsl", "Test generating DSL from implementation"
    def test_generate_dsl(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      post rest_url("component_module/test_generate_dsl"),{:component_module_id => component_module_id}
    end

    desc "MODULE-NAME/ID dsl-upgrade [UPGRADE-VERSION] [-v MODULE-VERSION]","Component module DSL upgrade"
    version_method_option
    def dsl_upgrade(context_params)
      component_module_id, dsl_version = context_params.retrieve_arguments([:module_id, :option_1],method_argument_names)
      dsl_version ||= MostRecentDSLVersion
      post_body = {
        :component_module_id => component_module_id,
        :dsl_version => dsl_version
      }
      post_body.merge!(:version => options["version"]) if options["version"]
       post rest_url("component_module/create_new_dsl_version"),post_body
    end
    MostRecentDSLVersion = 2
### end

    #### create and delete commands ###
    desc "delete MODULE-IDENTIFIER [-v VERSION] [-y] [-p]", "Delete component module or component module version and all items contained in it. Optional parameter [-p] is to delete local directory."
    version_method_option
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    def delete(context_params)
      module_location, modules_path = nil, nil
      component_module_id, force_delete = context_params.retrieve_arguments([:option_1!, :option_2],method_argument_names)
      version = options["version"]

      unless (options.force? || force_delete)
        # Ask user if really want to delete component module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete component-module #{version.nil? ? '' : 'version '}'#{component_module_id}#{version.nil? ? '' : ('-' + version.to_s)}' and all items contained in it"+'?')
      end

      #get component module name if component module id is provided on input - to be able to delete component module from local filesystem later
      component_module_id = get_module_name(component_module_id) if component_module_id.to_s =~ /^[0-9]+$/

      post_body = {
       :component_module_id => component_module_id
      }

      action = (options.version? ? "delete_version" : "delete")
      post_body[:version] = options.version if options.version?
      
      response = post(rest_url("component_module/#{action}"), post_body)
      return response unless response.ok?
      
      module_name = response.data(:module_name)
      Helper(:git_repo).unlink_local_clone?(:component_module,module_name,version)
      
      # when changing context send request for getting latest modules instead of getting from cache
      @@invalidate_map << :module_component

      # delete local module directory
      if options.purge?
        modules_path        = OsUtil.module_clone_location()
        module_location     = "#{modules_path}/#{component_module_id}" unless component_module_id.nil?
        module_location     = module_location + "-#{version}" if options.version?
        pwd                 = Dir.getwd()

        if (pwd == module_location)
          DTK::Client::OsUtil.print("Local directory '#{module_location}' is not deleted because it is your current working directory.", :yellow) 
          
          puts "You have successfully deleted component module '#{component_module_id}'."
          return response
        end

        FileUtils.rm_rf("#{module_location}") if (File.directory?(module_location) && ("#{modules_path}/" != module_location))
        
        unless options.version?
          module_versions = Dir.entries(modules_path).select{|a| a.match(/#{component_module_id}-\d.\d.\d/)}
          module_versions.each do |version|
            FileUtils.rm_rf("#{modules_path}/#{version}") if File.directory?("#{modules_path}/#{version}")
          end
        end
      end

      puts "You have successfully deleted component module '#{component_module_id}'."
      return response
    end


    desc "MODULE-NAME/ID set ATTRIBUTE-ID VALUE", "Set value of module attributes"
    def set(context_params)

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

      post rest_url("component_module/info"), post_body
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
      post_body        = (options.remote? ? {} : {:detail_to_include => ["remotes","versions"]})
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
        :detail_to_include => ["remotes"]
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
      module_info_about(context_params, :attributes, :attribute_w_version)
    end

    desc "MODULE-NAME/ID list-instances", "List all instances for given component module."
    def list_instances(context_params)
      module_info_about(context_params, :instances, :component)
    end

    desc "list-diffs","List difference between workspace and library component modules"
    def list_diffs()
      response = get rest_url("component_module/get_all_workspace_library_diffs")
      response.render_table(:list_diffs)
    end

    #### end: list and info commands ###

    #### commands to interact with remote repo ###


    desc "import MODULE-NAME", "Create new module from local clone"
    def import(context_params)
      module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      
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

      if response.data(:dsl_parsed_info)
        dsl_parsed_message = "Module '#{module_name}' imported with errors:\n#{response.data(:dsl_parsed_info)}\nYou can fix errors and import module again.\n"
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
      context_params.add_context_to_params("module", "module", module_id)
      push_clone_changes(context_params)

      response
    end

    desc "MODULE-NAME/ID reparse [-v VERSION]", "Check module for syntax errors in json/yaml files."
    version_method_option
    def reparse(context_params)
      module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      module_name = get_module_name(module_id)
      version = options["version"]

      modules_path    = OsUtil.module_clone_location()
      module_location = "#{modules_path}/#{module_name}#{version && "-#{version}"}"

      raise DTK::Client::DtkValidationError, "Unable to parse module '#{module_name}#{version && "-#{version}"}' that doesn't exist on your local machine!" unless File.directory?(module_location)

      reparse_aux(module_location)
    end
    
    # TODO: put in back support for:desc "import REMOTE-MODULE[,...] [LIBRARY-NAME/ID]", "Import remote component module(s) into library"
    # TODO: put in doc REMOTE-MODULE havs namespace and optionally version information; e.g. r8/hdp or r8/hdp/v1.1
    # if multiple items and failire; stops on first failure
    desc "import-r8n NAMESPACE/REMOTE-MODULE-NAME [-r R8-REPO-MANAGER]","Import remote component module into local environment"
    method_option "repo-manager",:aliases => "-r" ,
      :type => :string, 
      :banner => "REPO-MANAGER",
      :desc => "R8 Repo Manager from which to resolve requested module."
    def import_r8n(context_params)
      create_missing_clone_dirs()
      remote_module_name, version = context_params.retrieve_arguments([:option_1!, :option_2],method_argument_names)
      # in case of auto-import via service import, we skip cloning to speed up a process
      skip_cloning = context_params.get_forwarded_options()['skip_cloning'] if context_params.get_forwarded_options()

      remote_namespace, local_module_name = get_namespace_and_name(remote_module_name)
      if clone_dir = Helper(:git_repo).local_clone_dir_exists?(:component_module,local_module_name,version)
        raise DtkError,"Module's directory (#{clone_dir}) exists on client. To import this needs to be renamed or removed"
      end
      post_body = {
        :remote_module_name => remote_module_name,
        :local_module_name => local_module_name
      }
      response = post rest_url("component_module/import"), post_body

      return response unless response.ok?
      module_name,repo_url,branch,version = response.data(:module_name,:repo_url,:workspace_branch,:version)
      
      if response.data(:dsl_parsed_info)
        dsl_parsed_message = "Module '#{module_name}' imported with errors:\n#{response.data(:dsl_parsed_info)}\nYou can fix errors and import module again.\n"
        DTK::Client::OsUtil.print(dsl_parsed_message, :red) 
      end

      response = ""
      unless skip_cloning
        response = Helper(:git_repo).create_clone_with_branch(:component_module,module_name,repo_url,branch,version)
      end
      @@invalidate_map << :module_component

      puts "Component module '#{module_name}' imported successfully."
      response
    end

    #
    # Creates component module from input git repo, removing .git dir to rid of pointing to user github, and creates component module
    #
    desc "import-git MODULE-NAME GIT-SSH-REPO-URL", "Create new local module by importing from provided git repo URL"
    def import_git(context_params)
      module_name, git_repo_url = context_params.retrieve_arguments([:option_1!, :option_2!],method_argument_names)
      
      # Create component module from user's input git repo
      response = Helper(:git_repo).create_clone_with_branch(:component_module, module_name, git_repo_url)
      
      # Raise error if git repository is invalid
      # raise DtkError,"Git repository URL '#{git_repo_url}' is invalid." unless response.ok?
      return response unless response.ok?

      # Remove .git directory to rid of git pointing to user's github
      FileUtils.rm_rf("#{response['data']['module_directory']}/.git")
      
      # Reuse module create method to create module from local component_module
      create_response = import(context_params)

      # If server response is not ok, delete cloned module, invoke delete method and notify user about cleanup process.
      unless create_response.ok?
        FileUtils.rm_rf("#{response['data']['module_directory']}")
        context_params.method_arguments << "force_delete"
        delete(context_params)
        create_response['errors'][0]['message'] += "\nModule '#{module_name}' data is deleted."
      end



      return create_response
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
      #TODO: need to check if local clone directory exists
      Helper(:git_repo).create_clone_with_branch(:component_module,module_name,repo_url,branch,version)
    end
    
    desc "delete-remote [NAME-SPACE/]REMOTE-MODULE [-y]", "Delete remote component module"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_remote(context_params)
      remote_module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      remote_namespace, remote_name = get_namespace_and_name(remote_module_name)

      unless options.force?
        # Ask user if really want to delete component module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete remote component-module '#{remote_namespace.nil? ? '' : remote_namespace+'/'}#{remote_name}' and all items contained in it"+'?')
      end

      post_body = {
       :remote_module_name      => remote_name,
       :remote_module_namespace => remote_namespace
      }
      post rest_url("component_module/delete_remote"), post_body
    end

    desc "MODULE-NAME/ID export [[NAME-SPACE/]REMOTE-MODULE-NAME]", "Export component module to remote repository."
    def export(context_params)
      component_module_id, input_remote_name = context_params.retrieve_arguments([:module_id!, :option_1],method_argument_names)

      post_body = {
        :component_module_id     => component_module_id,
        :remote_component_name      => input_remote_name
      }

      response = post rest_url("component_module/export"), post_body
      
      return response         
    end

    desc "MODULE-NAME/ID push-to-remote [-n NAMESPACE] [-v VERSION]", "Push local copy of component module to remote repository."
    version_method_option
    method_option "namespace",:aliases => "-n",
        :type => :string, 
        :banner => "NAMESPACE",
        :desc => "Remote namespace"
    def push_to_remote(context_params)
      component_module_id, component_module_name = context_params.retrieve_arguments([:module_id!, :module_name!],method_argument_names)
      version = options["version"]

      if component_module_name.to_s =~ /^[0-9]+$/
        module_id   = component_module_name
        component_module_name = get_module_name(module_id)
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

    desc "MODULE-NAME/ID pull-from-remote [-v VERSION]", "Update local component module from remote repository."
    version_method_option
    def pull_from_remote(context_params)     
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      pull_from_remote_aux(:component_module,component_module_id,options["version"])
    end

    #### end: commands to interact with remote repo ###

    #### commands to manage workspace and versioning ###
    desc "MODULE-NAME/ID create-version VERSION", "Snapshot current state of module as a new version"
    def create_version(context_params)
      component_module_id,version = context_params.retrieve_arguments([:module_id!,:option_1!],method_argument_names)
      component_module_name = nil

      post_body = {
        :component_module_id => component_module_id,
        :version => version
      }

      response = post rest_url("component_module/create_new_version"), post_body
      return response unless response.ok?

      if component_module_id.to_s =~ /^[0-9]+$/
        component_module_name = get_module_name(component_module_id)
      end

      modules_path    = OsUtil.module_clone_location()
      module_location = "#{modules_path}/#{component_module_name}#{version && "-#{version}"}"

      raise DTK::Client::DtkValidationError, "Trying to clone a module '#{component_module_name}#{version && "-#{version}"}' that exists already!" if File.directory?(module_location)
      clone_aux(:component_module,component_module_id,version,true)
    end

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method in such way that edit will not be 
    #                   triggered after it.
    #
    desc "MODULE-NAME/ID clone [-v VERSION] [-n]", "Clone into client the component module files. Use -n to skip edit prompt."
    method_option :skip_edit, :aliases => '-n', :type => :boolean, :default => false
    version_method_option
    def clone(context_params, internal_trigger=false)
      thor_options = context_params.get_forwarded_options() || options
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      module_name         = context_params.retrieve_arguments([:module_id],method_argument_names)
      version             = thor_options["version"]
      internal_trigger    = true if thor_options['skip_edit']   

      # if this is not name it will not work, we need module name
      if module_name.to_s =~ /^[0-9]+$/
        module_id   = module_name
        module_name = get_module_name(module_id)
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
      module_name         = context_params.retrieve_arguments([:module_id],method_argument_names)
      version             = options.version||context_params.retrieve_arguments([:option_1],method_argument_names)

      # if this is not name it will not work, we need module name
      if module_name.to_s =~ /^[0-9]+$/
        module_id   = module_name
        module_name = get_module_name(module_id)
      end

      edit_aux(:component_module,module_id,module_name,version)
    end

    desc "MODULE-NAME/ID push-clone-changes [-v VERSION] [-m COMMIT-MSG]", "Push changes from local copy of module to server"
    version_method_option
    method_option "message",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def push_clone_changes(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      push_clone_changes_aux(:component_module,component_module_id,options["version"],options["message"]||DEFAULT_COMMIT_MSG)
    end

    desc "MODULE-NAME/ID list-diffs [-v VERSION] [--remote]", "List diffs"
    version_method_option
    method_option :remote, :type => :boolean, :default => false
    def list_diffs(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      module_name         = context_params.retrieve_arguments([:module_id],method_argument_names)
      version             = options["version"]

      # if this is not name it will not work, we need module name
      if module_name.to_s =~ /^[0-9]+$/
        module_id   = module_name
        module_name = get_module_name(module_id)
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

