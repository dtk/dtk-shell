dtk_require_from_base("commands/thor/assembly")

module DTK::Client

  class Workspace < Assembly


    def self.get_workspace_object()
      response = CommandBaseThor.get_cached_response(:workspace, "assembly/workspace_object", {})

      raise DTK::Client::DtkError.new("Workspace could not be found.") if !response.ok? || response.data.first.nil?

      response.data.first
    end


    no_tasks do

      def send(symbol,*args)
        workspace_object = Workspace.get_workspace_object()
        args.first.add_context_to_params(:assembly, :assembly, workspace_object['id']) if args.first
        __send__(symbol,*args)
      end

    end

  end

end