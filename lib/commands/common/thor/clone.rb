dtk_require_common_commands('thor/common')
module DTK::Client
  module CloneMixin
    extend Console
    include CommonMixin
    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    # module_type: will be :component_module or :service_module

    def clone_aux(module_type,module_id,version,internal_trigger,omit_output=false,opts={})
      module_name,repo_url,branch,not_ok_response = workspace_branch_info(module_type,module_id,version,opts)
      return not_ok_response if not_ok_response
      response = Helper(:git_repo).create_clone_with_branch(module_type,module_name,repo_url,branch,version,opts)

      if response.ok?
        puts "Module '#{module_name}' has been successfully cloned!" unless omit_output
        unless internal_trigger
          if Console.confirmation_prompt("Would you like to edit cloned module now?")
            if module_type.to_s.start_with?("service")
              context_params_for_module = create_context_for_module(module_name, :"service-module")
            else
              context_params_for_module = create_context_for_module(module_name, :"component-module")
            end
            return edit(context_params_for_module)
          end
        end
      end
      response
    end

    def create_context_for_module(module_name, module_type)
      context_params_for_module = DTK::Shell::ContextParams.new
      context_params_for_module.add_context_to_params(module_name, "#{module_type}", module_name)
      return context_params_for_module
    end
  end
end
