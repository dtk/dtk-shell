module DTK::Client
  class NodeTemplate < CommandBaseThor

    desc "NODE-NAME/ID info", "Get information about given node template."
    def info(node_id=nil)
      not_implemented()
    end

    desc "NODE-NAME/ID list targets", "List all components for given node template."
    def list(targets, node_id=nil)
      not_implemented()
    end

    desc "NODE-NAME/ID stage TARGET-NAME/ID", "Stage indentified target for given node template."
    def stage(target_id, node_id=nil)
      not_implemented()
    end

  end
end

