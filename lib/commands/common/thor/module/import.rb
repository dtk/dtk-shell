#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
dtk_require_from_base("util/os_util")
dtk_require_from_base('commands')
dtk_require_from_base("command_helper")

module DTK::Client
  class CommonModule
    class Import < BaseCommandHelper
      include CommandBase
      include CommandHelperMixin
      include PushCloneChangesMixin
      include ReparseMixin

      def from_git(internal_trigger = false)
        OsUtil.print('Retrieving git module data, please wait ...') unless internal_trigger

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

        unless internal_trigger
          OsUtil.print("Successfully installed #{ModuleUtil.module_name(module_type)} '#{ModuleUtil.join_name(@module_name, @module_namespace)}' from git.", :green)
        end
      end

      def from_file()
        module_type = @command.get_module_type(@context_params)
        module_name = retrieve_arguments([:option_1!])
        opts        = {}
        namespace, local_module_name = get_namespace_and_name(module_name, ModuleUtil::NAMESPACE_SEPERATOR)

        response = from_git_or_file()
        return response unless response.ok?

        opts_pull = {
          :local_branch => @branch,
          :namespace    => @module_namespace
        }
        resp = Helper(:git_repo).pull_changes(module_type, @module_name, opts_pull)
        return resp unless resp.ok?

        if error = response.data(:dsl_parse_error)
          dsl_parsed_message = ServiceImporter.error_message(module_name, error)
          DTK::Client::OsUtil.print(dsl_parsed_message, :red)
        end

        # remove source directory if no errors while importing
        module_final_dir = @repo_obj.repo_dir
        if @old_dir and (@old_dir != module_final_dir)
          FileUtils.rm_rf(@old_dir) unless namespace
        end

        if external_dependencies = response.data(:external_dependencies)
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

        if git_import
          module_git_url, module_name = @context_params.retrieve_arguments([:option_1!, :option_2!])
        else
          module_name, module_git_url = @context_params.retrieve_arguments([:option_1!, :option_2!])
        end

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
          :module_namespace => namespace,
          :module_git_url   => module_git_url
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

        if git_import
          post_body.merge!(:git_import => true)
        else
          post_body.merge!(:update_from_includes => true)
        end

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
