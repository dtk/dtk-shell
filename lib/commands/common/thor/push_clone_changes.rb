dtk_require_common_commands('thor/common')
dtk_require_from_base('command_helpers/service_importer')

module DTK::Client
  module PushCloneChangesMixin
    include CommonMixin
    ##
    #
    # module_type: will be :component_module or :service_module
    def push_clone_changes_aux(module_type,module_id,version,commit_msg,internal_trigger=false,opts={})
      module_name,module_namespace,repo_url,branch,not_ok_response = workspace_branch_info(module_type,module_id,version,opts)
      return not_ok_response if not_ok_response

      full_module_name = ModuleUtil.resolve_name(module_name, module_namespace)
      module_location  = OsUtil.module_location(module_type,full_module_name,version,opts)

      unless File.directory?(module_location)
        if Console.confirmation_prompt("Push not possible, module '#{module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          clone_aux(module_type,module_id, version, true, true, opts)
        else
          return
        end
      end

      push_opts = opts.merge(:commit_msg => commit_msg, :local_branch => branch)
      response = Helper(:git_repo).push_changes(module_type,full_module_name,version,push_opts)
      return response unless response.ok?

      json_diffs = (response.data(:diffs).empty? ? {} : JSON.generate(response.data(:diffs)))
      commit_sha = response.data(:commit_sha)
      repo_obj = response.data(:repo_obj)
      json_diffs = JSON.generate(response.data(:diffs))
      post_body = get_workspace_branch_info_post_body(module_type,module_id,version,opts).merge(:json_diffs => json_diffs, :commit_sha => commit_sha)
      post_body.merge!(:modification_type => opts[:modification_type]) if opts[:modification_type]
      post_body.merge!(:force_parse => true) if options['force-parse']

      response = post(rest_url("#{module_type}/update_model_from_clone"),post_body)
      return response unless response.ok?

      ret = Response::Ok.new()

      # check if any errors
      if dsl_parsed_info = response.data(:dsl_parsed_info)
        if dsl_parsed_message = ServiceImporter.error_message(module_name, dsl_parsed_info)
          DTK::Client::OsUtil.print(dsl_parsed_message, :red)
          ret = Response::NoOp.new()
        end
      end
      
      # check if server pushed anything that needs to be pulled
      dsl_updated_info = response.data(:dsl_updated_info)
      if dsl_updated_info and !dsl_updated_info.empty?
        if msg = dsl_updated_info["msg"] 
          DTK::Client::OsUtil.print(msg,:yellow)
        end
        new_commit_sha = dsl_updated_info[:commit_sha]
        unless new_commit_sha and new_commit_sha == commit_sha
          opts_pull = opts.merge(:local_branch => branch,:namespace => module_namespace)
          response = Helper(:git_repo).pull_changes(module_type,module_name,opts_pull)
          return response unless response.ok?
        end
      end

      # check if server sent any file that should be added
      dsl_created_info = response.data(:dsl_created_info)
      if dsl_created_info and !dsl_created_info.empty?
        path = dsl_created_info["path"]
        content = dsl_created_info["content"]
        if path and content
          msg = "A #{path} file has been created for you, located at #{repo_obj.repo_dir}" 
          response = Helper(:git_repo).add_file(path,content,msg)
          return response unless response.ok?
        end
      end
      ret
    end
  end
end
