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

    def clone_aux(module_type, module_id,version,internal_trigger=false,omit_output=false,opts={})
      module_name,module_namespace,repo_url,branch,not_ok_response = workspace_branch_info(module_type,module_id,version,opts)
      full_module_name = ModuleUtil.resolve_name(module_name, module_namespace)

      return not_ok_response if not_ok_response
      # TODO: should we use instead Helper(:git_repo).create_clone_from_optional_branch
      response = Helper(:git_repo).create_clone_with_branch(module_type,module_name,repo_url,branch,version,module_namespace,opts)

      if response.ok?
        puts "Module '#{full_module_name}' has been successfully cloned!" unless omit_output
        unless internal_trigger
          if Console.confirmation_prompt("Would you like to edit cloned module now?")
            context_params_for_module = create_context_for_module(full_module_name, module_type)
            return edit(context_params_for_module)
            # if module_type.to_s.eql?("service_module")
            #   context_params_for_module = create_context_for_module(module_name, :"service-module")
            # elsif module_type.to_s.eql?("component_module")
            #   context_params_for_module = create_context_for_module(module_name, :"component-module")
            # elsif module_type.to_s.eql?("test_module")
            #   context_params_for_module = create_context_for_module(module_name, :"test-module")
            # end
          end
        end
      end
      response
    end

    def create_context_for_module(full_module_name, module_type)
      context_params_for_module = DTK::Shell::ContextParams.new
      context_params_for_module.add_context_to_params(full_module_name, module_type.to_s.gsub!(/\_/,'-').to_sym, full_module_name)
      return context_params_for_module
    end
  end
end
