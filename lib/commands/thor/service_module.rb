#TODO: may be consistent on whether service module id or service module name used as params
dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_from_base('command_helpers/git_repo')
module DTK::Client
  class ServiceModule < CommandBaseThor
    def self.pretty_print_cols()
      PPColumns::SERVICE_MODULE
    end
    desc "list [library|remote]","List library, workspace,or remote service modules"
    def list(parent="library")
      case parent
       when "library":
         post rest_url("service_module/list_from_library")
       when "remote":
         post rest_url("service_module/list_remote")
       else 
         ResponseBadParams.new("module type" => parent)
      end
    end

    # TODO: Duplicate of library import ... should we delete this one?
    desc "import REMOTE-SERVICE-MODULE-NAME [library_id]", "Import remote service module into library"
    def import(service_module_name,library_id=nil)
      post_body = {
       :remote_module_name => service_module_name
      }
      post_body.merge!(:library_id => library_id) if library_id
      post rest_url("service_module/import"), post_body
    end

    desc "export SERVICE-MODULE-NAME/ID", "Export service module to remote repo"
    def export(service_module_id,library_id=nil)
      post_body = {
       :service_module_id => service_module_id
      }
      post rest_url("service_module/export"), post_body
    end

    desc "list-assemblies SERVICE-MODULE-ID","List assemblies in the service module"
    def list_assemblies(service_module_id)
      post_body = {
       :service_module_id => service_module_id
      }
      post rest_url("service_module/list_assemblies"), post_body
    end

    # TODO: Check to see if we are deleting this
    desc "create MODULE-NAME [library_id]", "Create an empty service module in library"
    def create(module_name,library_id=nil)
      post_body = {
       :module_name => module_name
      }
      post_body.merge!(:library_id => library_id) if library_id
      post rest_url("service_module/create"), post_body
    end

    desc "delete SERVICE-MODULE-ID", "Delete service module and all items contained in it"
    def delete(service_module_id)
      post_body = {
       :service_module_id => service_module_id
      }
      post rest_url("service_module/delete"), post_body
    end

    desc "add-direct-access [PATH-TO-RSA-PUB-KEY]","Adds direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def add_direct_access(path_to_key=nil)
      path_to_key ||= SshProcessing.default_rsa_pub_key_path()
      unless File.file?(path_to_key)
        raise DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        :rsa_pub_key => rsa_pub_key.chomp
      }
      response = post(rest_url("service_module/add_user_direct_access"),post_body)
      return response unless response.ok?
      repo_manager_footprint,repo_manager_dns = response.data_ret_and_remove!(:repo_manager_footprint,:repo_manager_dns)
      SshProcessing.update_ssh_known_hosts(repo_manager_dns,repo_manager_footprint)
      response
    end

    desc "remove-direct-access [PATH-TO-RSA-PUB-KEY]","Removes direct access to modules. Optional paramaeters is path to a ssh rsa public key and default is <user-home-dir>/.ssh/id_rsa.pub"
    def remove_direct_access(path_to_key=nil)
      path_to_key ||= "#{ENV['HOME']}/.ssh/id_rsa.pub" #TODO: very brittle
      unless File.file?(path_to_key)
        raise  DTK::Client::DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end
      rsa_pub_key = File.open(path_to_key){|f|f.read}
      post_body = {
        :rsa_pub_key => rsa_pub_key.chomp
      }
      post rest_url("service_module/remove_user_direct_access"), post_body
    end

    desc "create-jenkins-project SERVICE-MODULE-ID", "Create Jenkins project for service module"
    def create_jenkins_project(service_module_id)
      #require put here so dont necessarily have to install jenkins client gems

      dtk_require_from_base('command_helpers/jenkins_client')
      response = get rest_url("service_module/workspace_branch_info/#{service_module_id.to_s}")
      unless response.ok?
        errors_message = ''
        response['errors'].each { |error| errors_message += ", reason='#{error['code']}' message='#{error['message']}'" }
        raise DTK::Client::DtkError, "Invalid jenkins response#{errors_message}"
      end
      module_name,repo_url,branch = response.data_ret_and_remove!(:module_name,:repo_url,:branch)
      JenkinsClient.create_service_module_project?(service_module_id,module_name,repo_url,branch)
      #TODO: right now JenkinsClient wil throw error if problem; better to create an error resonse
      response
    end
  end
end

