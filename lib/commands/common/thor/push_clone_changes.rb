dtk_require_common_commands('thor/common')
dtk_require_from_base('command_helpers/service_importer')

module DTK::Client
  module PushCloneChangesMixin
    include CommonMixin
    ##
    #
    # module_type: will be :component_module or :service_module
    def push_clone_changes_aux(module_type,module_id,version,commit_msg,internal_trigger=false,opts={})
      module_name, module_namespace, repo_url, branch, not_ok_response = workspace_branch_info(module_type, module_id, version, opts)
      return not_ok_response if not_ok_response

      full_module_name = ModuleUtil.resolve_name(module_name, module_namespace)
      module_location  = OsUtil.module_location(module_type, full_module_name, version, opts)

      unless File.directory?(module_location)
        return if opts[:skip_cloning]
        if Console.confirmation_prompt("Push not possible, module '#{module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          clone_aux(module_type, module_id, version, true, true, opts)
        else
          return
        end
      end

      push_opts = opts.merge(:commit_msg => commit_msg, :local_branch => branch)
      response  = Helper(:git_repo).push_changes(module_type, full_module_name, version, push_opts)
      return response unless response.ok?

      json_diffs = (response.data(:diffs).empty? ? {} : JSON.generate(response.data(:diffs)))
      commit_sha = response.data(:commit_sha)
      repo_obj   = response.data(:repo_obj)
      json_diffs = JSON.generate(response.data(:diffs))
      post_body  = get_workspace_branch_info_post_body(module_type, module_id, version, opts).merge(:json_diffs => json_diffs, :commit_sha => commit_sha)
      post_body.merge!(:modification_type => opts[:modification_type]) if opts[:modification_type]
      post_body.merge!(:force_parse => true) if options['force-parse'] || opts[:force_parse]
      post_body.merge!(:skip_module_ref_update => true) if opts[:skip_module_ref_update]
      post_body.merge!(:update_from_includes => true) if opts[:update_from_includes]

      if opts[:set_parsed_false]
        post_body.merge!(:set_parsed_false => true)
        post_body.merge!(:force_parse => true)
      end

      response = post(rest_url("#{module_type}/update_model_from_clone"), post_body)
      return response unless response.ok?

      ret = Response::Ok.new()
      external_dependencies = response.data('external_dependencies')

      # check if any errors
      if dsl_parsed_info = response.data(:dsl_parsed_info)
        if parsed_external_dependencies = dsl_parsed_info['external_dependencies']
          external_dependencies = parsed_external_dependencies
        elsif dsl_parsed_message = ServiceImporter.error_message(module_name, dsl_parsed_info)
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
          response = Helper(:git_repo).pull_changes(module_type, module_name, opts_pull)
          return response unless response.ok?
        end
      end

      unless internal_trigger
        if external_dependencies
          ambiguous        = external_dependencies["ambiguous"]||[]
          amb_sorted       = ambiguous.map { |k,v| "#{k.split('/').last} (#{v.join(', ')})" }
          inconsistent     = external_dependencies["inconsistent"]||[]
          possibly_missing = external_dependencies["possibly_missing"]||[]
          OsUtil.print("There are inconsistent module dependencies: #{inconsistent.join(', ')}", :red) unless inconsistent.empty?
          OsUtil.print("There are missing module dependencies: #{possibly_missing.join(', ')}", :yellow) unless possibly_missing.empty?
          OsUtil.print("There are ambiguous module dependencies: '#{amb_sorted.join(', ')}'. One of the namespaces should be selected by editing the module_refs file", :yellow) if ambiguous && !ambiguous.empty?
        end
      end

      # check if server sent any file that should be added
      dsl_created_info = response.data(:dsl_created_info)
      if dsl_created_info and !dsl_created_info.empty?
        path = dsl_created_info["path"]
        content = dsl_created_info["content"]
        if path and content
          msg      = "A #{path} file has been created for you, located at #{repo_obj.repo_dir}"
          response = Helper(:git_repo).add_file(repo_obj,path,content,msg)
          return response unless response.ok?
        end
      end
      ret
    end
  end
end
