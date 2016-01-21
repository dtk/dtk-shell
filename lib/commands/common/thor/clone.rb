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

    def clone_aux(module_type, module_id, version, internal_trigger = false, omit_output = false, opts = {})
      # if version = base do not clone latest, just base
      if version && version.eql?('base')
        version = nil
        opts[:use_latest] = false
      end

      module_name, module_namespace, repo_url, branch, not_ok_response, version = workspace_branch_info(module_type, module_id, version, opts)
      return not_ok_response if not_ok_response

      # clone base version first if not cloned already
      clone_base_aux(module_type, module_id, "#{module_namespace}:#{module_name}") if opts[:use_latest] && version

      # TODO: DTK-2358: comenyed out because causing error in this jira; see if need to put in in revisedform to avoid this error; below is checking wromg thing ( module_location is set to wromg thing to check)
      # module_location = OsUtil.module_location(module_type, "#{module_namespace}:#{module_name}", version)
      # raise DTK::Client::DtkValidationError, "#{module_type.to_s.gsub('_',' ').capitalize} '#{module_name}#{version && "-#{version}"}' already cloned!" if File.directory?(module_location) && !opts[:skip_if_exist_check]

      full_module_name = ModuleUtil.resolve_name(module_name, module_namespace)

      # TODO: should we use instead Helper(:git_repo).create_clone_from_optional_branch
      response = Helper(:git_repo).create_clone_with_branch(module_type,module_name,repo_url,branch,version,module_namespace,opts)

      if response.ok?
        print_name = "Module '#{full_module_name}'"
        print_name << " version '#{version}'" if version
        puts "#{print_name} has been successfully cloned!" unless omit_output
        # when puppet forge import, print successfully imported instead of cloned
        DTK::Client::OsUtil.print("#{print_name} has been successfully imported!", :yellow) if omit_output && opts[:print_imported]
        unless internal_trigger
          if Console.confirmation_prompt("Would you like to edit module now?")
            context_params_for_module = create_context_for_module(full_module_name, module_type)
            return edit(context_params_for_module)
          end
        end
      end

      response
    end

    # clone base module version
    def clone_base_aux(module_type, module_id, full_module_name)
      base_module_location = OsUtil.module_location(module_type, full_module_name, nil)
      unless File.directory?(base_module_location)
        clone_aux(module_type, module_id, nil, true)
      end
    end

    def create_context_for_module(full_module_name, module_type)
      context_params_for_module = DTK::Shell::ContextParams.new
      context_params_for_module.add_context_to_params(full_module_name, module_type.to_s.gsub!(/\_/,'-').to_sym, full_module_name)
      return context_params_for_module
    end
  end
end
