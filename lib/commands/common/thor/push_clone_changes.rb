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
dtk_require_common_commands('thor/common')
dtk_require_from_base('command_helpers/service_importer')

module DTK::Client
  module PushCloneChangesMixin
    include CommonMixin
    ##
    #
    # module_type: will be :component_module or :service_module
    def push_clone_changes_aux(module_type, module_id, version, commit_msg, internal_trigger=false, opts={})
      module_name, module_namespace, repo_url, branch, not_ok_response = workspace_branch_info(module_type, module_id, version, opts)
      return not_ok_response if not_ok_response

      full_module_name = ModuleUtil.resolve_name(module_name, module_namespace)
      module_location  = OsUtil.module_location(module_type, full_module_name, version, opts)

      unless File.directory?(module_location)
        return if opts[:skip_cloning]
        if opts[:force_clone] || Console.confirmation_prompt("Push not possible, module '#{module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          clone_aux(module_type, module_id, version, true, true, opts)
        else
          return
        end
      end

      push_opts = opts.merge(:commit_msg => commit_msg, :local_branch => branch, :where => 'server')
      response  = Helper(:git_repo).push_changes(module_type, full_module_name, version, push_opts)
      return response unless response.ok?

      json_diffs = (response.data(:diffs).empty? ? {} : JSON.generate(response.data(:diffs)))
      commit_sha = response.data(:commit_sha)
      repo_obj   = response.data(:repo_obj)
      json_diffs = JSON.generate(response.data(:diffs))
      post_body  = get_workspace_branch_info_post_body(module_type, module_id, version, opts).merge(:json_diffs => json_diffs, :commit_sha => commit_sha)

      post_body.merge!(:modification_type => opts[:modification_type]) if opts[:modification_type]
      post_body.merge!(:force_parse => true) if options['force-parse'] || opts[:force_parse]
      post_body.merge!(:update_from_includes => true) if opts[:update_from_includes]
      post_body.merge!(:service_instance_module => true) if opts[:service_instance_module]
      post_body.merge!(:current_branch_sha => opts[:current_branch_sha]) if opts[:current_branch_sha]
      post_body.merge!(:force => opts[:force]) if opts[:force]
      post_body.merge!(:task_action => opts[:task_action]) if opts[:task_action]
      post_body.merge!(:generate_docs => true) if opts[:generate_docs]
      post_body.merge!(:use_impl_id => opts[:use_impl_id]) if opts[:use_impl_id]

      if opts[:set_parsed_false]
        post_body.merge!(:set_parsed_false => true)
        post_body.merge!(:force_parse => true)
      end

      response = post(rest_url("#{module_type}/update_model_from_clone"), post_body)

      if pull_changes = response.data(:pull_changes)
        opts_pull = opts.merge(:local_branch => branch,:namespace => module_namespace)
        Helper(:git_repo).pull_changes(module_type, module_name, opts_pull)
      end

      return response unless response.ok?

      external_dependencies = response.data(:external_dependencies)
      dsl_parse_error       = response.data(:dsl_parse_error)
      dsl_updated_info      = response.data(:dsl_updated_info)
      dsl_created_info      = response.data(:dsl_created_info)
      component_module_refs = response.data(:component_module_refs)

      ret = Response::Ok.new()

      # check if any errors
      if dsl_parse_error
        if parsed_external_dependencies = dsl_parse_error['external_dependencies']
          external_dependencies = parsed_external_dependencies
        else
          err_msg_opts = { :module_type => module_type }
          err_msg_opts.merge!(:command => opts[:command]) if opts[:command]
          if err_message = ServiceImporter.error_message(module_name, dsl_parse_error, err_msg_opts)
            DTK::Client::OsUtil.print(err_message, :red)
            ret = Response::NoOp.new()
          end
        end
      end

      has_code_been_pulled = false

      # check if server pushed anything that needs to be pulled

      # we need to pull latest code in case docs where generated
      OsUtil.print("Pulling generated documentation on your local repository ...", :yellow) if opts[:generate_docs]

      if dsl_updated_info and !dsl_updated_info.empty?
        if msg = dsl_updated_info["msg"]
          DTK::Client::OsUtil.print(msg,:yellow)
        end
        new_commit_sha = dsl_updated_info[:commit_sha]
        unless new_commit_sha and new_commit_sha == commit_sha
          opts_pull = opts.merge(:local_branch => branch,:namespace => module_namespace)
          resp = Helper(:git_repo).pull_changes(module_type, module_name, opts_pull)
          has_code_been_pulled = true
          return resp unless resp.ok?
        end
      end

      # unless DSL was updated we pull latest code due to changes on documentation
      if opts[:generate_docs] && !has_code_been_pulled
        opts_pull = opts.merge(:local_branch => branch,:namespace => module_namespace)
        resp = Helper(:git_repo).pull_changes(module_type, module_name, opts_pull)
        return resp unless resp.ok?
      end

      if opts[:print_dependencies] || !internal_trigger
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
      if dsl_created_info and !dsl_created_info.empty?
        path = dsl_created_info["path"]
        content = dsl_created_info["content"]
        if path and content
          msg      = "A #{path} file has been created for you, located at #{repo_obj.repo_dir}"
          response = Helper(:git_repo).add_file(repo_obj,path,content,msg)
          return response unless response.ok?
        end
      end

      unless (component_module_refs||{}).empty?
        print_using_dependencies(component_module_refs)
      end

      ret
    end

    private

    def print_using_dependencies(component_refs)
      # TODO: This just prints out dircetly included modules
      unless component_refs.empty?
        puts 'Using component modules:'
        component_refs.values.map { |r| "#{r['namespace_info']}:#{r['module_name']}" }.sort.each do |name|
          puts "  #{name}"
        end
      end
    end
  end
end
