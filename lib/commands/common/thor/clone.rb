module DTK::Client
  module CloneMixin

    extend Console
    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    # module_type: will be :component_module or :service_module

    def clone_aux(module_type,module_id,version,internal_trigger,omit_output=false,opts={})
      id_field = "#{module_type}_id"
      post_body = {
        id_field => module_id
      }
      post_body.merge!(:version => version) if version
      if assembly_module = opts[:assembly]
        post_body.merge!(:assembly_module => true,:assembly_name => assembly_module[:assembly_name])
      end

      response = post(rest_url("#{module_type}/get_workspace_branch_info"),post_body)
      return response unless response.ok?

      module_name,repo_url,branch = response.data(:module_name,:repo_url,:workspace_branch)
      response = Helper(:git_repo).create_clone_with_branch(module_type,module_name,repo_url,branch,version,opts)

      if response.ok?
        puts "Module '#{module_name}' has been successfully cloned!" unless omit_output
        unless internal_trigger
          if Console.confirmation_prompt("Would you like to edit cloned module now?")
            if module_type.to_s.start_with?("service")
              context_params_for_module = create_context_for_module(module_name, "service")
            else
              context_params_for_module = create_context_for_module(module_name, "module")
            end
            return edit(context_params_for_module)
          end
        end
      end
      response
    end

    def create_context_for_module(module_name, module_type)
      context_params_for_module = DTK::Shell::ContextParams.new
      context_params_for_module.add_context_to_params("#{module_type}", "#{module_type}", module_name)
      return context_params_for_module
    end

  end
end
