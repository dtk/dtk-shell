module DTK
  module Client

    #
    # This class is used to reroute commands/tasks (Method invocations) from one context (Class) to another
    #
    class ContextRouter

      # This method invokes target context task
      def self.routeTask(target_context, target_method, target_context_params, conn)

        # Initing required params and invoking target_context.target_method
        load_command(target_context)
        target_context_class = DTK::Client.const_get "#{cap_form(target_context)}"

        return target_context_class.execute_from_cli(conn, target_method, target_context_params, [], false)
      end

    end

  end
end
