module DTK::Client
  class ModuleComponent < CommandBaseThor

    #### create and delete commands ###
    desc "delete COMPONENT-MODULE-NAME/ID", "Delete component module and all items contained in it"
    def delete(component_module_id)
      post_body = {
       :component_module_id => component_module_id
      }
      response = post(rest_url("component_module/delete"), post_body)
      return response unless response.ok?
      module_name = response.data(:module_name)
      dtk_require_from_base('command_helpers/git_repo')
      GitRepo.unlink_local_clone?(:component_module,module_name)
    end

    desc "create COMPONENT-MODULE-NAME [LIBRARY-NAME/ID]", "Create new module from local clone"
    def create(arg1,arg2=nil)
      module_name, library_id = (arg2.nil? ? [arg1] : [arg2,arg1])

      dtk_require_from_base('command_helpers/git_repo')

      #first check that there is a directory there and it is not already a git repo
      response = GitRepo.check_local_dir_exists(:component_module,module_name)
      return response unless response.ok?

      #first make call to server to create an empty repo
      post_body = {
       :component_module_name => module_name
      }
      post_body.merge!(:library_id => library_id) if library_id
      response = post rest_url("component_module/create_empty_repo"), post_body
      return response unless response.ok?

      repo_url,repo_id,library_id = response.data(:repo_url,:repo_id,:library_id)
      branch_info = {
        :workspace => response.data(:workspace_branch),
        :library => response.data(:library_branch)
      }
      response = GitRepo.initialize_repo_and_push(:component_module,module_name,branch_info,repo_url)
      return response unless response.ok?

      post_body = {
        :repo_id => repo_id,
        :library_id => library_id,
        :module_name => module_name
      }
      post rest_url("component_module/update_repo_and_add_meta_data"), post_body
    end

    #### end: create and delete commands ###

    #### list and info commands ###
    desc "COMPONENT-MODULE-NAME/ID info", "Get information about given component module."
    def info(component_module_id)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/info"), post_body
    end

    desc "[COMPONENT-MODULE-NAME/ID] list [component] [--remote]", "List all components for given component module."
    method_option :list, :type => :boolean, :default => false
    method_option :remote, :type => :boolean, :default => false
    def list(targets='none', component_module_id=nil)
      post_body = {
        :component_module_id => component_module_id,
        :about => targets
      }

      case targets
      when 'none'
        action = (options.remote? ? "list_remote" : "list")
        response = post rest_url("component_module/#{action}")
        data_type = DataType::COMPONENT
      when 'components'
        if options.remote?
          #TODO: this is temp; will shortly support this
          raise DTK::Client::DtkError, "Not supported '--remote' option when listing components in component modules"
        end
        response = post rest_url("component_module/list"), post_body
        data_type = DataType::COMPONENT
      else
        raise DTK::Client::DtkError, "Not supported type '#{targets}' for given command."
      end

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "list-diffs","List difference between workspace and library component modules"
    def list_diffs()
      response = get rest_url("component_module/get_all_workspace_library_diffs")
pp response.data
      response.render_table(DataType::DIFF)
    end

    #### end: list and info commands ###

    #### commands to interact with remote repo ###
    desc "import REMOTE-MODULE[,...] [LIBRARY-NAME/ID]", "Import remote component module(s) into library"
    #TODO: put in doc REMOTE-MODULE havs namespace and optionally version information; e.g. r8/hdp or r8/hdp/v1.1
    #if multiple items and failire; stops on first failure
    def import(remote_modules, library_id=nil)
      post_body = {
       :remote_module_names => remote_modules.split(",")
      }
      post_body.merge!(:library_id => library_id) if library_id

      post rest_url("component_module/import"), post_body
    end

    desc "delete-remote REMOTE-MODULE", "Delete remote component module"
    def delete_remote(remote_module_name)
      post_body = {
       :remote_module_name => remote_module_name
      }
      post rest_url("component_module/delete_remote"), post_body
    end


    desc "COMPONENT-MODULE-NAME/ID export", "Export component module remote repository."
    def export(component_module_id)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/export"), post_body
    end

    desc "COMPONENT-MODULE-NAME/ID push-to-remote", "Push local copy of component module to remote repository."
    def push_to_remote(component_module_id)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/push_to_remote"), post_body
    end

    desc "COMPONENT-MODULE-NAME/ID pull-from-remote", "Update local component module from remote repository."
    def pull_from_remote(component_module_id)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/pull_from_remote"), post_body
    end

    #### end: commands to interact with remote repo ###

    #### commands to manage workspace and promote changes from workspace to library ###
    desc "COMPONENT-MODULE-NAME/ID promote-to-library [VERSION]", "Update library module with changes from workspace"
    def promote_to_library(arg1,arg2=nil)
      #component_module_id is in last position, which coudl be arg1 or arg2
      component_module_id,version = (arg2 ? [arg2,arg1] : [arg1])

      post_body = {
        :component_module_id => component_module_id
      }
      post_body.merge!(:version => version) if version

      post rest_url("component_module/promote_to_library"), post_body
    end

    #TODO: may also provide an optional library argument to create in new library
    desc "COMPONENT-MODULE-NAME/ID promote-new-version [EXISTING-VERSION] NEW-VERSION", "Promote workspace module as new version of module in library from workspace"
    def promote_new_version(arg1,arg2,arg3=nil)
      #component_module_id is in last position
      component_module_id,new_version,existing_version = 
        (arg3 ? [arg3,arg2,arg1] : [arg2,arg1])

      post_body = {
        :component_module_id => component_module_id,
        :new_version => new_version
      }
      if existing_version
        post_body.merge!(:existing_version => existing_version)
      end

      post rest_url("component_module/promote_as_new_version"), post_body
    end

    #### end: commands to manage workspace and promote changes from workspace to library ###

    #### end: commands related to cloning to and pushing from local clone
    desc "COMPONENT-MODULE-NAME/ID clone [VERSION]", "Clone into client the component module files"
    def clone(arg1,arg2=nil)
      component_module_id,version = (arg2.nil? ? [arg1] : [arg2,arg1]) 
      post_body = {
        :component_module_id => component_module_id
      }
      post_body.merge!(:version => version) if version

      response = post(rest_url("component_module/create_workspace_branch"),post_body)
      return response unless response.ok?

      module_name,repo_url,branch = response.data(:module_name,:repo_url,:workspace_branch)
      dtk_require_from_base('command_helpers/git_repo')
      response = GitRepo.create_clone_with_branch(:component_module,module_name,repo_url,branch,version)
      response
    end

    desc "COMPONENT-MODULE-NAME/ID push-clone-changes [VERSION]", "Push changes from local copy of module to server"
    def push_clone_changes(arg1,arg2=nil)
      component_module_id,version = (arg2.nil? ? [arg1] : [arg2,arg1])
      post_body = {
        :component_module_id => component_module_id
      }
      post_body.merge!(:version => version) if version 

      response =  post(rest_url("component_module/workspace_branch_info"),post_body) 
      return response unless response.ok?

      dtk_require_from_base('command_helpers/git_repo')
      response = GitRepo.push_changes(:component_module,response.data(:module_name))
      return response unless response.ok?
      pp [:diffs,response]

      post_body.merge!(:diffs => response.data(:diffs))

      post rest_url("component_module/update_model_from_clone"), post_body
    end

    #### end: commands related to cloning to and pushing from local clone

    #TODO: add-direct-access and remove-direct-access should be removed as commands and instead add-direct-access 
    #Change from having module-command/add_direct_access to being a command to being done when client is installed if user wants this option
    desc "add-direct-access [PATH-TO-RSA-PUB-KEY]","Adds direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def add_direct_access(path_to_key=nil)
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
      repo_manager_footprint,repo_manager_dns = response.data_ret_and_remove!(:repo_manager_footprint,:repo_manager_dns)
      SshProcessing.update_ssh_known_hosts(repo_manager_dns,repo_manager_footprint)
      response
    end

    desc "remove-direct-access [PATH-TO-RSA-PUB-KEY]","Removes direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def remove_direct_access(path_to_key=nil)
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

    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn = conn if @conn.nil?
        response = nil
        
        response = post rest_url("component_module/list")
        
        unless response.nil?
          response['data'].each do |element|
            return true if (element['id'].to_s==value || element['display_name'].to_s==value)
          end
        end
        return false
      end

      def self.get_identifiers(conn)
        @conn = conn if @conn.nil?
        response = nil
        
        response = post rest_url("component_module/list")
        
        unless response.nil?
          identifiers = []
          response['data'].each do |element|
            identifiers << element['display_name']
          end
          return identifiers
        end
        return []
      end
    end

  end
end

