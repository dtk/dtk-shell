dtk_require_common_commands('thor/common')
module DTK::Client
  module PushToRemoteMixin

    ##
    #
    # module_type: will be :component_module or :service_module
    # def push_to_remote_aux(module_type,module_id, module_name,remote_namespace,version=nil)
    def push_to_remote_aux(remote_module_info, module_type)
      # commented out, because we perform this check before calling 'push_to_remote_aux' from service-module/component-module
      # id_field = "#{module_type}_id"

      # rsa_pub_value = SSHUtil.rsa_pub_key_content()

      # post_body = {
      #   id_field => module_id,
      #   :rsa_pub_key => rsa_pub_value,
      #   :access_rights => "rw",
      #   :action => "push"
      # }
      # post_body.merge!(:version => version) if version
      # post_body.merge!(:remote_namespace => remote_namespace) if remote_namespace

      # response = post(rest_url("#{module_type}/get_remote_module_info"),post_body)
      # return response unless response.ok?

      returned_module_name = remote_module_info.data(:module_name)
      version = remote_module_info.data(:version)

      opts = {
        :remote_repo_url => remote_module_info.data(:remote_repo_url),
        :remote_repo => remote_module_info.data(:remote_repo),
        :remote_branch => remote_module_info.data(:remote_branch),
        :local_branch => remote_module_info.data(:workspace_branch)
      }

      response = Helper(:git_repo).push_changes(module_type,returned_module_name,version,opts)
      return response unless response.ok?
      if response.data(:diffs).empty?
        raise DtkError, "No changes to push"
      end
      
      Response::Ok.new()
    end

  end
end
