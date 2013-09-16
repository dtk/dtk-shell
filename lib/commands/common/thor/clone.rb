module DTK::Client
  module CloneMixin
    extend Console
    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    # module_type: will be :component_module or :service_module

    def clone_aux(module_type,module_id,version,internal_trigger,omit_output=false,opts={})
      module_name,repo_url,branch,not_ok_response = module_info(module_type,module_id,version,opts)
      return not_ok_response if not_ok_response
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
   private
    #returns module_name,repo_url,branch,not_ok_response( only if error)
    def module_info(module_type,module_id,version,opts={})
      module_name = opts[:module_name]
      repo_url = opts[:repo_url]
      branch = opts[:branch]
      if module_name and repo_url and branch
        [module_name,repo_url,branch]
      else
        id_field = "#{module_type}_id"
        post_body = {
          id_field => module_id
        }
        post_body.merge!(:version => version) if version
        if assembly_module = opts[:assembly_module]
          post_body.merge!(:assembly_module => true,:assembly_name => assembly_module[:assembly_name])
        end
        response = post(rest_url("#{module_type}/get_workspace_branch_info"),post_body)
        unless response.ok?
          [nil,nil,nil,response]
        else
          response.data(:module_name,:repo_url,:workspace_branch)
        end
      end
    end
  end
end
