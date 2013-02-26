dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_dtk_common('grit_adapter')
dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/push_to_remote')
dtk_require_common_commands('thor/pull_from_remote')
dtk_require_common_commands('thor/push_clone_changes')
require 'fileutils'

module DTK::Client
  class Module < CommandBaseThor

    no_tasks do
      include CloneMixin
      include PushToRemoteMixin
      include PullFromRemoteMixin
      include PushCloneChangesMixin

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

    desc "MODULE-NAME/ID dsl-upgrade [UPGRADE-VERSION]","Component module DSL upgrade"
    def dsl_upgrade(context_params)
      component_module_id, dsl_version = context_params.retrieve_arguments([:module_id, :option_1],method_argument_names)
      dsl_version ||= MostRecentDSLVersion
      post_body = {
        :component_module_id => component_module_id,
        :dsl_version => dsl_version
      }
       post rest_url("component_module/create_new_dsl_version"),post_body
    end
    MostRecentDSLVersion = 2
### end

    #### create and delete commands ###
    desc "delete MODULE-IDENTIFIER", "Delete component module and all items contained in it"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete(context_params)
      component_module_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
     unless options.force?
        # Ask user if really want to delete component module and all items contained in it, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete component-module '#{component_module_id}' and all items contained in it"+'?')
      end

      post_body = {
       :component_module_id => component_module_id
      }
      response = post(rest_url("component_module/delete"), post_body)
      return response unless response.ok?
      module_name = response.data(:module_name)
      Helper(:git_repo).unlink_local_clone?(:component_module,module_name)
      # when changing context send request for getting latest modules instead of getting from cache
      @@invalidate_map << :module_component
    end

    #
    # Creates component module from input git repo, removing .git dir to rid of pointing to user github, and creates component module
    #
    desc "import-from-git MODULE-NAME GIT-REPO-URL", "Create new local module by importing from provided git repo URL"
    def import_from_git(context_params)
      module_name, git_repo_url = context_params.retrieve_arguments([:option_1!, :option_2!],method_argument_names)

      # Create component module from user's input git repo
      response = Helper(:git_repo).create_clone_with_branch(:component_module, module_name, git_repo_url)

      # Remove .git directory to rid of git pointing to user's github
      FileUtils.rm_rf("#{response['data']['module_directory']}/.git")
      
      # Reuse module create method to create module from local component_module
      return create(context_params)
    end

    desc "create MODULE-NAME", "Create new module from local clone"
    def create(context_params)
      module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      
      #first check that there is a directory there and it is not already a git repo, and it ha appropriate content
      response = Helper(:git_repo).check_local_dir_exists_with_content(:component_module,module_name)
      return response unless response.ok?
      module_directory = response.data(:module_directory)

      #first make call to server to create an empty repo
      post_body = {
        :module_name => module_name
      }
      response = post rest_url("component_module/create"), post_body
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

      dsl_created_info = response.data(:dsl_created_info)
      if dsl_created_info and !dsl_created_info.empty?
        msg = "First cut of dsl file (#{dsl_created_info["path"]}) has been created in module directory (#{module_directory}); edit and then invoke 'dtk module #{module_name} push-clone-changes'"
        response = Helper(:git_repo).add_file(repo_obj,dsl_created_info["path"],dsl_created_info["content"],msg)
      else
        response = Response::Ok.new("module_created" => module_name)
      end
      response
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

    desc "list [--remote]", "List library or component remote component modules."
    method_option :remote, :type => :boolean, :default => false
    def list(context_params)
      action = (options.remote? ? "list_remote" : "list")
      response = post rest_url("component_module/#{action}")
      data_type = :component
      response.render_table(:component)
    end

    # Optionally TODO if needed: change method to be consistent with service/id>assembly-template list
    desc "MODULE-NAME/ID list-components", "List all components for given component module."
    #TODO: support info on remote
    def list_components(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      post_body = {
        :component_module_id => component_module_id,
        :about => 'components'
      }
      response = post rest_url("component_module/info_about"), post_body
      data_type = :component
      response.render_table(data_type) unless options.list?
    end

    desc "list-diffs","List difference between workspace and library component modules"
    def list_diffs()
      response = get rest_url("component_module/get_all_workspace_library_diffs")
      response.render_table(:module_diff)
    end

    #### end: list and info commands ###

    #### commands to interact with remote repo ###
    
    #TODO: put in back support for:desc "import REMOTE-MODULE[,...] [LIBRARY-NAME/ID]", "Import remote component module(s) into library"
    #TODO: put in doc REMOTE-MODULE havs namespace and optionally version information; e.g. r8/hdp or r8/hdp/v1.1
    #if multiple items and failire; stops on first failure
    desc "import REMOTE-MODULE-NAME","Import remote component module into local environment"
    def import(context_params)
      remote_module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      local_module_name = remote_module_name
      if clone_dir = Helper(:git_repo).local_clone_dir_exists?(:component_module,local_module_name)
        raise DtkError,"Module's directory (#{clone_dir}) exists on client. To import this needs to be renamed or removed"
      end
      post_body = {
        :remote_module_name => remote_module_name,
        :local_module_name => local_module_name
      }
      response = post rest_url("component_module/import"), post_body
      @@invalidate_map << :module_component

      return response unless response.ok?
      module_name,repo_url,branch,version = response.data(:module_name,:repo_url,:workspace_branch,:version)
      Helper(:git_repo).create_clone_with_branch(:component_module,module_name,repo_url,branch,version)
    end

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
    
    desc "delete-remote REMOTE-MODULE", "Delete remote component module"
    def delete_remote(context_params)
      remote_module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      post_body = {
       :remote_module_name => remote_module_name
      }
      post rest_url("component_module/delete_remote"), post_body
    end

    desc "MODULE-NAME/ID export", "Export component module to remote repository."
    def export(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/export"), post_body
    end

    desc "MODULE-NAME/ID push-to-remote [-v VERSION]", "Push local copy of component module to remote repository."
    version_method_option
    def push_to_remote(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      push_to_remote_aux(:component_module,component_module_id,options["version"])
    end

    desc "MODULE-NAME/ID pull-from-remote [-v VERSION]", "Update local component module from remote repository."
    version_method_option
    def pull_from_remote(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      pull_from_remote_aux(:component_module,component_module_id,options["version"])
    end

    #### end: commands to interact with remote repo ###

    #### commands to manage workspace and versioning ###
    desc "MODULE-NAME/ID create-new-version NEW-VERSION", "Snapshot current state of module as a new version"
    def create_new_version(context_params)
      component_module_id,version = context_params.retrieve_arguments([:module_id!,:option_1!],method_argument_names)
      post_body = {
        :component_module_id => component_module_id,
        :version => version
      }

      post rest_url("component_module/create_new_version"), post_body
    end

    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    #
    desc "MODULE-NAME/ID clone [-v VERSION]", "Clone into client the component module files"
    version_method_option
    def clone(context_params, internal_trigger=false)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      module_name         = context_params.retrieve_arguments([:module_id],method_argument_names)
      version             = options["version"]

      # if this is not name it will not work, we need module name
      if module_name.to_s =~ /^[0-9]+$/
        module_id   = module_name
        module_name = get_module_name(module_id)
      end

      modules_path    = OsUtil.module_clone_location(::Config::Configuration.get(:module_location))
      module_location = "#{modules_path}/#{module_name}#{version && "-#{version}"}"

      raise DTK::Client::DtkValidationError, "Trying to clone a module '#{module_name}#{version && "-#{version}"}' that exists already!" if File.directory?(module_location)
      clone_aux(:component_module,component_module_id,version,internal_trigger)
    end

    desc "MODULE-NAME/ID edit [-v VERSION]","Switch to unix editing for given module."
    version_method_option
    def edit(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      module_name         = context_params.retrieve_arguments([:module_id],method_argument_names)
      version             = options["version"]

      # if this is not name it will not work, we need module name
      if module_name.to_s =~ /^[0-9]+$/
        module_id   = module_name
        module_name = get_module_name(module_id)
      end

      modules_path    = OsUtil.module_clone_location(::Config::Configuration.get(:module_location))
      module_location = "#{modules_path}/#{module_name}#{version && "-#{version}"}"

      # check if there is repository cloned 
      unless File.directory?(module_location)
        if Console.confirmation_prompt("Edit not possible, module '#{module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          # context_params_for_module = create_context_for_module(module_name, "module")
          # response = clone(context_params_for_module,true)
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

      # here we should have desired module cloned
      Console.unix_shell(module_location, component_module_id, :component_module, version)
      grit_adapter = DTK::Common::GritAdapter::FileAccess.new(module_location)

      if grit_adapter.changed?
        grit_adapter.print_status

        # check to see if auto commit flag
        auto_commit  = ::Config::Configuration.get(:auto_commit_changes)
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

    desc "MODULE-NAME/ID push-clone-changes [-v VERSION] [-m COMMIT-MSG]", "Push changes from local copy of module to server"
    version_method_option
    method_option "message",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def push_clone_changes(context_params)
      component_module_id = context_params.retrieve_arguments([:module_id!],method_argument_names)
      push_clone_changes_aux(:component_module,component_module_id,options["version"],options["message"])
    end

    #### end: commands related to cloning to and pushing from local clone


    #TODO: add-direct-access and remove-direct-access should be removed as commands and instead add-direct-access 
    #Change from having module-command/add_direct_access to being a command to being done when client is installed if user wants this option
    desc "add-direct-access [PATH-TO-RSA-PUB-KEY]","Adds direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def add_direct_access(context_params)
      path_to_key = context_params.retrieve_arguments([:option_1],method_argument_names)

      path_to_key ||= SshProcessing.default_rsa_pub_key_path()
      unless File.file?(path_to_key)
        raise DTK::Client::DtkError, "No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        :rsa_pub_key => rsa_pub_key.chomp
      }
      response = post(rest_url("component_module/add_user_direct_access"),post_body)
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
        raise DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        :rsa_pub_key => rsa_pub_key.chomp
      }
      post rest_url("component_module/remove_user_direct_access"), post_body
    end
  end
end

