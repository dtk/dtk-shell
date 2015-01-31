dtk_require_from_base("util/os_util")
dtk_require_from_base('commands')
dtk_require_from_base("command_helper")

module DTK::Client
  class CommonModule
    class Import < self
      include CommandBase
      include CommandHelperMixin
      include PushCloneChangesMixin
      include ReparseMixin

      def from_git()
        git_repo_url, module_name    = retrieve_arguments([:option_1!, :option_2!])
        namespace, local_module_name = get_namespace_and_name(module_name, ModuleUtil::NAMESPACE_SEPERATOR)
        
        module_type  = @command.get_module_type(@context_params)
        thor_options = { :git_import => true}
        
        unless namespace
          namespace_response = post rest_url("namespace/default_namespace_name")
          return namespace_response unless namespace_response.ok?

          namespace = namespace_response.data
          thor_options[:default_namespace] = namespace
        end

        opts = {
          :namespace => namespace,
          :branch    => @options['branch']
        }
        response = Helper(:git_repo).create_clone_from_optional_branch(module_type.to_sym, local_module_name, git_repo_url, opts)
        return response unless response.ok?

        # Remove .git directory to rid of git pointing to user's github
        FileUtils.rm_rf("#{response['data']['module_directory']}/.git")

        @context_params.forward_options(thor_options)
        create_response = from_git_or_file()

        unless create_response.ok?
          delete_dir        = namespace.nil? ? local_module_name : "#{namespace}/#{local_module_name}"
          full_module_name  = create_response.data[:full_module_name]
          local_module_name = full_module_name.nil? ? delete_dir : full_module_name

          @command.delete_module_sub_aux(@context_params, local_module_name, :force_delete => true, :no_error_msg => true, :purge => true)
          return create_response
        end

        opts_pull = {
          :local_branch => @branch,
          :namespace    => @module_namespace
        }
        pull_response = Helper(:git_repo).pull_changes(module_type, @module_name, opts_pull)
        return pull_response unless pull_response.ok?

        if external_dependencies = create_response.data(:external_dependencies)
          print_external_dependencies(external_dependencies, 'in the git repo')
        end

        Response::Ok.new()
      end

      def from_file()
        module_type = @command.get_module_type(@context_params)
        module_name = retrieve_arguments([:option_1!])
        opts        = {}
        namespace, local_module_name = get_namespace_and_name(module_name, ModuleUtil::NAMESPACE_SEPERATOR)

        response = from_git_or_file()
        return response unless response.ok?

        dsl_updated_info      = response.data(:dsl_updated_info)
        dsl_created_info      = response.data(:dsl_created_info)
        external_dependencies = response.data(:external_dependencies)

        if dsl_updated_info and !dsl_updated_info.empty?
          new_commit_sha = dsl_updated_info[:commit_sha]
          unless new_commit_sha and new_commit_sha == commit_sha
            opts_pull = {
              :local_branch => @branch,
              :namespace    => @module_namespace
            }
            resp = Helper(:git_repo).pull_changes(module_type, @module_name, opts_pull)
            return resp unless resp.ok?
          end
        end

        push_needed      = false
        module_final_dir = @repo_obj.repo_dir

        if dsl_created_info and !dsl_created_info.empty?
          path = dsl_created_info["path"]
          msg  = "A #{path} file has been created for you, located at #{module_final_dir}"
          if content = dsl_created_info["content"]
            resp = Helper(:git_repo).add_file(@repo_obj, path, content, msg)
            return resp unless resp.ok?
            push_needed = true
          end
        end

        ##### code that does push that can be removed once we always do commit of dsl on server side
        if push_needed
          if external_dependencies
            ambiguous        = external_dependencies['ambiguous']||[]
            possibly_missing = external_dependencies["possibly_missing"]||[]
            opts.merge!(:set_parsed_false => true, :skip_module_ref_update => true) unless ambiguous.empty? && possibly_missing.empty?
          end

          @context_params.add_context_to_params(local_module_name, module_type.to_s.gsub!(/\_/,'-').to_sym, @module_id)
          response = @command.push_module_aux(@context_params, true, opts)

          if error = response.data(:dsl_parse_error)
            dsl_parsed_message = ServiceImporter.error_message(module_name, error)
            DTK::Client::OsUtil.print(dsl_parsed_message, :red)
          end

          unless response.ok?
            # remove new directory and leave the old one if import without namespace failed
            if @old_dir and (@old_dir != module_final_dir)
              FileUtils.rm_rf(module_final_dir) unless namespace
            end
            return response
          end
        end
        ##### end: code that does push

        # remove source directory if no errors while importing
        if @old_dir and (@old_dir != module_final_dir)
          FileUtils.rm_rf(@old_dir) unless namespace
        end

        if external_dependencies
          print_external_dependencies(external_dependencies, 'dtk.model.yaml includes')
        end

        # if user do import from default directory (e.g. import ntp - without namespace) print message
        DTK::Client::OsUtil.print("Module '#{@new_module_name}' has been created and module directory moved to #{module_final_dir}",:yellow) unless namespace

        Response::Ok.new()
      end


      private

      def from_git_or_file()
        default_ns = @context_params.get_forwarded_options()[:default_namespace]
        git_import = @context_params.get_forwarded_options()[:git_import]

        name_option = git_import ? :option_2! : :option_1!
        module_name = @context_params.retrieve_arguments([name_option])
        module_type = @command.get_module_type(@context_params)
        version     = @options["version"]

        # extract namespace and module_name from full name (r8:maven will result in namespace = r8 & name = maven)
        namespace, local_module_name = get_namespace_and_name(module_name, ModuleUtil::NAMESPACE_SEPERATOR)
        namespace = default_ns if default_ns && namespace.nil?

        # first check that there is a directory there and it is not already a git repo, and it ha appropriate content
        response = Helper(:git_repo).check_local_dir_exists_with_content(module_type.to_sym, local_module_name, nil, namespace)
        return response unless response.ok?

        #check for yaml/json parsing errors before import
        module_directory = response.data(:module_directory)
        reparse_aux(module_directory)

        # first make call to server to create an empty repo
        post_body = {
          :module_name => local_module_name,
          :module_namespace => namespace
        }
        response = post(rest_url("#{module_type}/create"), post_body)
        return response unless response.ok?

        repo_url, repo_id, @module_id, branch, @new_module_name = response.data(:repo_url, :repo_id, :module_id, :workspace_branch, :full_module_name)
        response = Helper(:git_repo).rename_and_initialize_clone_and_push(module_type.to_sym, local_module_name, @new_module_name, branch, repo_url, module_directory)
        return response unless (response && response.ok?)

        @repo_obj, commit_sha = response.data(:repo_obj, :commit_sha)
        module_final_dir      = @repo_obj.repo_dir
        @old_dir              = response.data[:old_dir]

        post_body = {
          :repo_id    => repo_id,
          :commit_sha => commit_sha,
          :commit_dsl => true,
          :scaffold_if_no_dsl => true,
          "#{module_type}_id".to_sym => @module_id
        }
        post_body.merge!(:git_import => true) if git_import
        response = post(rest_url("#{module_type}/update_from_initial_create"), post_body)

        unless response.ok?
          response.set_data_hash({ :full_module_name => @new_module_name })
          # remove new directory and leave the old one if import without namespace failed
          if @old_dir and (@old_dir != module_final_dir)
            FileUtils.rm_rf(module_final_dir) unless (namespace && git_import)
          end
          return response
        end

        dsl_updated_info = response.data(:dsl_updated_info)
        dsl_created_info = response.data(:dsl_created_info)
        DTK::Client::OsUtil.print("A module_refs.yaml file has been created for you, located at #{module_final_dir}", :yellow) if dsl_updated_info && !dsl_updated_info.empty?
        DTK::Client::OsUtil.print("A #{dsl_created_info["path"]} file has been created for you, located at #{module_final_dir}", :yellow) if dsl_created_info && !dsl_created_info.empty?

        @module_name, @module_namespace, repo_url, @branch, not_ok_response = workspace_branch_info(module_type, @module_id, version)
        return not_ok_response if not_ok_response

        response
      end

    end
  end
end
