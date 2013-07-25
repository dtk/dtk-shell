module DTK::Client
  module PullFromRemoteMixin

    ##
    #
    # module_type: will be :component_module or :service_module

    def pull_from_remote_aux(module_type,module_id,version=nil)

      #get remote module info, errors raised if remote is not linked or access errors
      path_to_key = SshProcessing.default_rsa_pub_key_path()
      rsa_pub_key = File.file?(path_to_key) && File.open(path_to_key){|f|f.read}.chomp

      post_body = {
        PullFromRemote.id_field(module_type) => module_id,
        :access_rights => "r",
        :action => "pull"
      }
      post_body.merge!(:version => version) if version
      post_body.merge!(:rsa_pub_key => rsa_pub_key) if rsa_pub_key
      response = post(rest_url("#{module_type}/get_remote_module_info"),post_body)      
      return response unless response.ok?
      module_name = response.data(:module_name)
      remote_params = response.data_hash_form(:remote_repo_url,:remote_repo,:remote_branch)
      remote_params.merge!(:version => version) if version

      # check whether a local module exists to determine whether pull from local clone or try to pull from server
      if Helper(:git_repo).local_clone_exists?(module_type,module_name,version)
        unless rsa_pub_key
          raise DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
        end
        if module_type == :service_module
          post_body = {
            :service_module_id => module_id
          }
          response = post(rest_url("service_module/resolve_pull_from_remote"),post_body)

          print "Resolving dependencies please wait ... "
          
          if ((missing_components = response.data(:missing_modules)) && response.ok?)
            puts " New dependencies found, Installing."

            trigger_module_component_import(missing_components)
            puts "Resuming pull from remote ..."
            # repeat import call for service
            response = post rest_url("service_module/import"), post_body
          else
            puts 'Done.'
          end
              
        end
        PullFromRemote.perform_locally(self,module_type,module_id,module_name,remote_params)
      else
        PullFromRemote.perform_on_server(self,module_type,module_id,module_name,remote_params)
      end
    end
   private
    module PullFromRemote 
      extend CommandBase
      def self.perform_locally(cmd_obj,module_type,module_id,module_name,remote_params)
        opts = remote_params
        response = cmd_obj.Helper(:git_repo).pull_changes(module_type,module_name,opts)
        return response unless response.ok?

        if response.data[:diffs].empty?
          raise DtkError, "No changes to pull from remote"
        end
        
        # [Haris] - I do not undestand this second call and I am removing it
        #response = cmd_obj.Helper(:git_repo).pull_changes(module_type,module_name)
        #return response unless response.ok?

        #if response.data(:diffs).empty?
        #  raise DTK::Client::DtkError, "Unexepected that there are no diffs with workspace"
        #end
                
        post_body = {
          id_field(module_type) => module_id,
          :commit_sha => response.data[:commit_sha],
          :json_diffs => JSON.generate(response.data[:diffs])
        }
        post rest_url("#{module_type}/update_model_from_clone"), post_body
      end

      def self.perform_on_server(cmd_obj,module_type,module_id,module_name,remote_params)
        post_body = {
          id_field(module_type) => module_id,
          :remote_repo => remote_params[:remote_repo]
        }
        post_body.merge!(:version => remote_params[:version]) if remote_params[:version]
        post rest_url("#{module_type}/pull_from_remote"), post_body
      end
      
      def self.id_field(module_type)
        "#{module_type}_id"
      end

    end
  end
end
