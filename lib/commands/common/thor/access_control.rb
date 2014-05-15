module DTK::Client
  module AccessControlMixin

    def chmod_aux(module_id, permission_string, namespace = nil)
      permission_selector = PermissionUtil.validate_permissions!(permission_string.downcase)
      post_body = {
        :module_id => module_id,
        :permission_selector => permission_selector,
        :rsa_pub_key         => SSHUtil.rsa_pub_key_content(),
        :remote_module_namespace => namespace
      }
      post rest_url("#{resolve_module_type}/remote_chmod"), post_body
    end

    def chown_aux(module_id, remote_user, namespace = nil)
      post_body = {
        :module_id => module_id,
        :remote_user => remote_user,
        :rsa_pub_key         => SSHUtil.rsa_pub_key_content(),
        :remote_module_namespace => namespace
      }
      post rest_url("#{resolve_module_type}/remote_chown"), post_body
    end

    def collaboration_aux(action, module_id, users, groups, namespace = nil)
      raise DtkValidationError, "You must provide --users or --groups to this command" if users.nil? && groups.nil?
      post_body = {
        :module_id => module_id,
        :users  => users,
        :groups => groups,
        :action => action,
        :remote_module_namespace => namespace,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }
      post rest_url("#{resolve_module_type}/remote_collaboration"), post_body
    end

    def collaboration_list_aux(module_id, namespace = nil)
      post_body = {
        :module_id => module_id,
        :remote_module_namespace => namespace,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }
      post rest_url("#{resolve_module_type}/list_remote_collaboration"), post_body
    end

  private

    def resolve_module_type
      self.class == DTK::Client::ComponentModule ? 'component_module' : 'service_module'
    end

  end
end