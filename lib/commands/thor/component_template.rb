module DTK::Client
  class ComponentTemplate < CommandBaseThor

    desc "COMPONENT-NAME/ID info", "Get information about given component template."
    def info(component_id=nil)
      not_implemented()
    end

    desc "COMPONENT-NAME/ID list nodes", "List all nodes for given component template."
    def list(targets, component_id=nil)
      not_implemented()
    end

    desc "COMPONENT-NAME/ID stage NODE-NAME/ID", "Stage indentified node for given component template."
    def stage(target_id, component_id=nil)
      not_implemented()
    end

  end
end

