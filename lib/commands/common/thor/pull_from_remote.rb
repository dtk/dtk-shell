module DTK::Client
  module PullFromRemoteMixin

    ##
    #
    # module_type: will be :component_module or :service_module

    def pull_from_remote_aux(module_type,module_id)
      #get remote module info, errors raised if remote is not linked or access errors
      path_to_key = SshProcessing.default_rsa_pub_key_path()
      rsa_pub_key = File.file?(path_to_key) && File.open(path_to_key){|f|f.read}.chomp

      post_body = {
        PullFromRemote.id_field(module_type) => module_id,
        :access_rights => "r",
        :action => "pull"
      }
      post_body.merge!(:rsa_pub_key => rsa_pub_key) if rsa_pub_key
      response = post(rest_url("#{module_type}/get_remote_module_info"),post_body)
      return response unless response.ok?
      module_name = response.data(:module_name)
      remote_params = response.data_hash_form(:remote_repo_url,:remote_repo,:remote_branch)

      #check whether a local module exists to determine whether pull from local clone or try to pull from server
      dtk_require_from_base('command_helpers/git_repo')
      if GitRepo.local_clone_exists?(module_type,module_name)
        unless rsa_pub_key
          raise DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
        end
        PullFromRemote.perform_locally(module_type,module_id,module_name,remote_params)
      else
        PullFromRemote.perform_on_server(module_type,module_id,module_name,remote_params)
      end
    end
   private
    module PullFromRemote 
      extend CommandBase
      def self.perform_locally(module_type,module_id,module_name,remote_params)
        opts = remote_params
        response = GitRepo.pull_changes(module_type,module_name,opts)
        return response unless response.ok?
        if response.data(:diffs).empty?
          raise DtkError, "No changes to pull from remote"
        end
        
        response = GitRepo.push_changes(module_type,module_name)
        return response unless response.ok?
        if response.data(:diffs).empty?
          raise DTK::Client::DtkError, "Unexepected that there are no diffs with workspace"
        end
        
        post_body = {
          id_field(module_type) => module_id,
          :json_diffs => JSON.generate(response.data(:diffs))
        }
        post rest_url("#{module_type}/update_model_from_clone"), post_body
      end

      def self.perform_on_server(module_type,module_id,module_name,remote_params)
        post_body = {
          id_field(module_type) => module_id,
          :remote_repo => remote_params[:remote_repo]
        }
        post rest_url("#{module_type}/pull_from_remote"), post_body
      end
      
      def self.id_field(module_type)
        "#{module_type}_id"
      end

    end
  end
end
