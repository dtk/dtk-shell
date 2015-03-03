module DTK::Client
  module AccessControlMixin

    def chmod_aux(module_id, permission_string, namespace = nil, chmod_action = :chmod)
      permission_selector = PermissionUtil.validate_permissions!(permission_string.downcase)
      post_body = {
        :module_id => module_id,
        :permission_selector => permission_selector,
        :chmod_action        => chmod_action,
        :rsa_pub_key         => SSHUtil.rsa_pub_key_content(),
        :remote_module_namespace => namespace
      }
      response = post rest_url("#{resolve_module_type}/remote_chmod"), post_body
      return response unless response.ok?

      if response.data(:simple_flow)
        puts "Module is now public."
      else
        # in case there are dependencies
        main_module_name = response.data(:main_module)['full_name']
        puts "Main module '#{main_module_name}' has dependencies that are not public: "
        unless response.data(:missing_modules).empty?
          missing = response.data(:missing_modules).collect { |a| a['full_name'] }
          OsUtil.print("  These modules are missing on repository: #{missing.join(', ')}", :red)
        end
        unless response.data(:no_permission).empty?
          no_permission = response.data(:no_permission).collect { |a| a['full_name'] }
          OsUtil.print("  You cannot change permissions for dependencies: #{no_permission.join(', ')}", :yellow)
        end
        unless response.data(:with_permission).empty?
          with_permission = response.data(:with_permission)
          with_permission_names = with_permission.collect { |a| a['full_name'] }
          OsUtil.print("  You can change permissions for dependencies: #{with_permission_names.join(', ')}", :white)

          # fix for bug in comments for DTK-1959
          # need to send hash instead of array to be able to parse properly in rest_request_params
          with_permission_hash = {}
          with_permission.each do |wp|
            with_permission_hash.merge!("#{wp['name']}" => wp)
          end

          response.data["with_permission"] = with_permission_hash
        end

        puts "How should we resolve these dependencies: "
        input = ::DTK::Shell::InteractiveWizard.resolve_input("(A)ll / (M)ain Module / (N)one ", ['M','A','N'], true)
        if 'N'.eql?(input)
          return nil
        else
          puts "Sending input information ... "
          post_body = {
            :module_id     => module_id,
            :module_info   => response.data,
            :public_action => 'A'.eql?(input) ? :all : :one,
            :rsa_pub_key   => SSHUtil.rsa_pub_key_content(),
            :remote_module_namespace => namespace
          }

          response = post rest_url("#{resolve_module_type}/confirm_make_public"), post_body
          return response unless response.ok?
          puts "Modules are now public."
        end
      end

      nil
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
      case self
        when DTK::Client::ComponentModule
          return :component_module
        when DTK::Client::ServiceModule
          return :service_module
        when DTK::Client::TestModule
          return :test_module
        else
          raise DtkError, "Module type cannot be resolved for this class (#{self})"
        end
    end

  end
end