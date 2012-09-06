module DTK::Client
  class ModuleComponent < CommandBaseThor

    desc "COMPONENT-MODULE-NAME/ID info", "Get information about given module component template."
    def info(component_module_id=nil)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/info"), post_body
    end

    desc "[COMPONENT-MODULE-NAME/ID] list [component]", "List all components for given component-module template."
    method_option :list, :type => :boolean, :default => false
    def list(targets='none', component_module_id=nil)
      post_body = {
        :component_module_id => component_module_id,
        :about => targets
      }

      case targets
      when 'none'
        response = post rest_url("component_module/list")
        data_type = DataType::COMPONENT
      when 'components'
        response = post rest_url("component_module/list"), post_body
        data_type = DataType::COMPONENT
      else
        raise DTK::Client::DtkError, "Not supported type '#{targets}' for given command."
      end

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "COMPONENT-MODULE-NAME/ID export", "Export module component template."
    def export(component_module_id=nil)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/export"), post_body
    end

    desc "COMPONENT-MODULE-NAME/ID pust-to-remote", "Push module component template to remote repository."
    def push_to_remote(component_module_id=nil)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/push_to_remote"), post_body
    end

    desc "COMPONENT-MODULE-NAME/ID pull_from_remote", "Pull module component template from remote repository."
    def pull_from_remote(component_module_id=nil)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/pull_from_remote"), post_body
    end

  end
end

