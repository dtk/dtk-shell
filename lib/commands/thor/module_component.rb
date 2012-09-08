module DTK::Client
  class ModuleComponent < CommandBaseThor

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

    desc "COMPONENT-MODULE-NAME/ID delete", "Delete component module and all items contained in it"
    def delete(component_module_id)
      post_body = {
       :component_module_id => component_module_id
      }
      post rest_url("component_module/delete"), post_body
    end

    #TODO: may also provide an optional library argument to create in new library
    desc "COMPONENT-MODULE-NAME/ID promote-to-library [NEW-VERSION]", "Update or create new version of workspace module in library"
    def promote_to_library(*args)
      #TODO: working around bug where arguments are rotated; below is just temp workaround to rotate back
      component_module_id,new_version = [args.last] + args[0..args.size-2]

      post_body = {
        :component_module_id => component_module_id
      }
      if new_version
        post_body.merge!(:new_version => new_version)
      end

      post rest_url("component_module/promote_to_library"), post_body
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

  end
end

