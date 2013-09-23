dtk_require_from_base("commands/thor/assembly")

module DTK::Client

  class Workspace < Assembly

    desc "ASSEMBLY-NAME/ID purge [-y]", "Purge the workspace, deleting and terminating any nodes that have been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def purge(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)
      unless options.force?
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy all nodes in the workspace"+'?')
      end

      post_body = {
        :assembly_id => assembly_id
      }
      response = post(rest_url("assembly/purge"),post_body)
    end

    # Method remove (list of methods from assembly that should not be available in workspace)
    [:delete_and_destroy, :list].each do |meth|
      self.superclass.remove_task(meth, { :undefine => false })
    end


    no_tasks do

      @workspace_object = nil

      # Important to set
      shadow_entity = true

      def list(context_params)
        []
      end
      
      def send(symbol,*args)
        @workspace_object = get_workspace_object()
        args.first.add_context_to_params(:assembly, :assembly, @workspace_object['id']) if args.first
        __send__(symbol,*args)
      end


      def get_workspace_object()
        return @workspace_object if @workspace_object
        response = CommandBaseThor.get_cached_response(:workspace, "assembly/workspace_object", {})

        raise DTK::Client::DtkError.new("Workspace could not be found.") if !response.ok? || response.data.first.nil?

        response.data.first
      end

    end

  end

end