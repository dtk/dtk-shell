module DTK::Client
  class ModuleComponentTemplate < CommandBaseThor

    desc "COMPONENT-MODULE-NAME/ID info", "Get information about given module component template."
    def info(component_module_id=nil)
      not_implemented()
    end

    desc "COMPONENT-MODULE-NAME/ID list component", "List all components for given component-module template."
    def list(targets, component_module_id=nil)
      not_implemented()
    end

    desc "COMPONENT-MODULE-NAME/ID export", "Export module component template."
    def export(component_module_id=nil)
      not_implemented()
    end

    desc "COMPONENT-MODULE-NAME/ID pust-to-remote", "Push module component template to remote repository."
    def push_to_remote(component_module_id=nil)
      not_implemented()
    end

    desc "COMPONENT-MODULE-NAME/ID pull_from_remote", "Pull module component template from remote repository."
    def pull_from_remote(component_module_id=nil)
      not_implemented()
    end

  end
end

