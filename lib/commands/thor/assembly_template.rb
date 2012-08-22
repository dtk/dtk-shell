module DTK::Client
  class AssemblyTemplate < CommandBaseThor

    desc "ASSEMBLY-NAME/ID info", "Get information about given assembly template."
    def info(assembly_id=nil)
      not_implemented()
    end

    desc "ASSEMBLY-NAME/ID list [nodes|components|targets]", "List all nodes/components/targets for given assembly template."
    def list(targets, assembly_id=nil)
      not_implemented()
    end

    desc "ASSEMBLY-NAME/ID stage TARGET-NAME/ID", "Stage indentified target for given assembly template."
    def stage(target_id, assembly_id=nil)
      not_implemented()
    end

  end
end

