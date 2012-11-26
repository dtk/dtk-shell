module DTK::Client
  module CloneMixin
    ##
    #
    # internal_trigger: this flag means that other method (internal) has trigger this.
    #                   This will change behaviour of method
    # module_type: will be :component_module or :service_module

    def clone_aux(module_type,module_id,version,internal_trigger)
      id_field = "#{module_type}_id"
      post_body = {
        id_field => module_id
      }
      post_body.merge!(:version => version) if version

      response = post(rest_url("#{module_type}/create_workspace_branch"),post_body)
      return response unless response.ok?

      module_name,repo_url,branch = response.data(:module_name,:repo_url,:workspace_branch)
      dtk_require_from_base('command_helpers/git_repo')
      response = GitRepo.create_clone_with_branch(module_type,module_name,repo_url,branch,version)

      if response.ok?
        puts "Module '#{module_name}' has been successfully cloned!"
        unless internal_trigger
          if confirmation_prompt("Would you like to edit cloned module now?")
            return edit(module_name)
          end
        end
      end
      response
    end
  end
end
