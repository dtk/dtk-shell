dtk_require_from_base("util/os_util")
dtk_require_common_commands('thor/push_clone_changes')
dtk_require_common_commands('thor/reparse')
dtk_require_common_commands('thor/common')

dtk_require_from_base('commands')
dtk_require_from_base("command_helper")

module DTK::Client
  class CommonModule
    class Import < self
      include CommandBase
      include CommandHelperMixin
      include PushCloneChangesMixin
      include ReparseMixin

      # For Rich: this is used for import-git
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

        if create_response.ok?
          module_name, module_namespace, repo_url, branch, not_ok_response = workspace_branch_info(module_type, create_response.data['module_id'], create_response.data['version'])
          create_response = not_ok_response if not_ok_response
        end

        unless create_response.ok?
          delete_dir        = namespace.nil? ? local_module_name : "#{namespace}/#{local_module_name}"
          full_module_name  = create_response.data[:full_module_name]
          local_module_name = full_module_name.nil? ? delete_dir : full_module_name

          @command.delete_module_sub_aux(@context_params, local_module_name, :force_delete => true, :no_error_msg => true, :purge => true)
          return create_response
        end

        opts_pull = {
          :local_branch => branch,
          :namespace => module_namespace
        }
        pull_response = Helper(:git_repo).pull_changes(module_type, module_name, opts_pull)
        return pull_response unless pull_response.ok?

        if external_dependencies = create_response.data(:external_dependencies)
          print_external_dependencies(external_dependencies, 'in the git repo')
        end

        Response::Ok.new()
      end

      # For Rich: this is for import
      def from_file()
        module_type = @command.get_module_type(@context_params)
        module_name = retrieve_arguments([:option_1!])
        namespace, local_module_name = get_namespace_and_name(module_name, ModuleUtil::NAMESPACE_SEPERATOR)
        opts = {}

        response = from_git_or_file()
        return response unless response.ok?

        repo_obj         = response.data['repo_obj']
        module_final_dir = repo_obj.repo_dir
        old_dir          = response.data['old_dir']
        new_module_name  = response.data['new_module_name']

        module_name, module_namespace, repo_url, branch, not_ok_response = workspace_branch_info(module_type, response.data['module_id'], response.data['version'])
        return not_ok_response if not_ok_response

        opts_pull = {
          :local_branch => branch,
          :namespace => module_namespace
        }

        dsl_updated_info      = response.data(:dsl_updated_info)
        dsl_created_info      = response.data(:dsl_created_info)
        external_dependencies = response.data(:external_dependencies)

        dsl_updated_info = response.data(:dsl_updated_info)
        if dsl_updated_info and !dsl_updated_info.empty?
          new_commit_sha = dsl_updated_info[:commit_sha]
          unless new_commit_sha and new_commit_sha == commit_sha
            resp = Helper(:git_repo).pull_changes(module_type, module_name, opts_pull)
            return resp unless resp.ok?
          end
        end

        # For Aldin; wil update the server side to  have dsl_created_info not have content when that is added on server side
        # so setting acondition wrt to this and casing on this, i.e., whether need to commit file and then do push
        # after we make sure working we can remove code that commits dsl file on client side
        push_needed = false
        if dsl_created_info and !dsl_created_info.empty?
          path = dsl_created_info["path"]
          msg = "A #{path} file has been created for you, located at #{module_final_dir}"
          if content = dsl_created_info["content"]
            resp = Helper(:git_repo).add_file(repo_obj, path, content, msg)
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

          @context_params.add_context_to_params(local_module_name, module_type.to_s.gsub!(/\_/,'-').to_sym, response.data['module_id'])
          response = push_module_aux(@context_params, true, opts)

          unless response.ok?
            # remove new directory and leave the old one if import without namespace failed
            if old_dir and (old_dir != module_final_dir)
              FileUtils.rm_rf(module_final_dir) unless namespace
            end
            return response
          end
        end
        ##### end: code that does push

        # remove source directory if no errors while importing
        if old_dir and (old_dir != module_final_dir)
          FileUtils.rm_rf(old_dir) unless namespace
        end

        if external_dependencies
          print_external_dependencies(external_dependencies, 'dtk.model.yaml includes')
        end

        # if user do import from default directory (e.g. import ntp - without namespace) print message
        DTK::Client::OsUtil.print("Module '#{new_module_name}' has been created and module directory moved to #{module_final_dir}",:yellow) unless namespace

        Response::Ok.new()
      end

      # For Rich: common code for import-git and import
      def from_git_or_file()
        default_ns = @context_params.get_forwarded_options()[:default_namespace]
        git_import = @context_params.get_forwarded_options()[:git_import]

        name_option = git_import ? :option_2! : :option_1!
        module_name = @context_params.retrieve_arguments([name_option])
        module_type = @command.get_module_type(@context_params)
        version     = @options["version"]
        create_response = {}

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

        repo_url,repo_id,module_id,branch,new_module_name = response.data(:repo_url, :repo_id, :module_id, :workspace_branch, :full_module_name)
        response = Helper(:git_repo).rename_and_initialize_clone_and_push(module_type.to_sym, local_module_name, new_module_name, branch, repo_url, module_directory)
        return response unless (response && response.ok?)

        repo_obj, commit_sha = response.data(:repo_obj, :commit_sha)
        module_final_dir     = repo_obj.repo_dir
        old_dir              = response.data[:old_dir]

        post_body = {
          :repo_id    => repo_id,
          :commit_sha => commit_sha,
          :commit_dsl => true,
          :scaffold_if_no_dsl => true,
          "#{module_type}_id".to_sym => module_id
        }
        post_body.merge!(:git_import => true) if git_import
        response = post(rest_url("#{module_type}/update_from_initial_create"), post_body)

        unless response.ok?
          response.set_data_hash({ :full_module_name => new_module_name })
          # remove new directory and leave the old one if import without namespace failed
          if old_dir and (old_dir != module_final_dir)
            FileUtils.rm_rf(module_final_dir) unless (namespace && git_import)
          end
          return response
        end

        dsl_updated_info      = response.data(:dsl_updated_info)
        dsl_created_info      = response.data(:dsl_created_info)
        external_dependencies = response.data(:external_dependencies)
        DTK::Client::OsUtil.print("A module_refs.yaml file has been created for you, located at #{module_final_dir}", :yellow) if dsl_updated_info && !dsl_updated_info.empty?
        DTK::Client::OsUtil.print("A #{dsl_created_info["path"]} file has been created for you, located at #{module_final_dir}", :yellow) if dsl_created_info && !dsl_created_info.empty?

        module_name, module_namespace, repo_url, branch, not_ok_response = workspace_branch_info(module_type, module_id, version)
        return not_ok_response if not_ok_response

        # For Rich: did not have time today, but should find better way to pass these arguments to from_git and from_file methods
        response.add_data_value!(:module_id, module_id)
        response.add_data_value!(:version, version)
        response.add_data_value!(:repo_obj, repo_obj)
        response.add_data_value!(:old_dir, old_dir)
        response.add_data_value!(:new_module_name, new_module_name)

        response
      end

      private
      # ... the methods that represent the basic steps of from_git and from_git_or_file
    end
  end
end
