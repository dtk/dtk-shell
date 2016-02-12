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
dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/list_diffs')
dtk_require_common_commands('thor/puppet_forge')
dtk_require_common_commands('thor/push_to_remote')
dtk_require_common_commands('thor/pull_from_remote')
dtk_require_common_commands('thor/push_clone_changes')
dtk_require_common_commands('thor/access_control')
dtk_require_common_commands('thor/edit')
dtk_require_common_commands('thor/reparse')
dtk_require_common_commands('thor/purge_clone')
dtk_require_common_commands('thor/common')
dtk_require_common_commands('thor/remotes')

dtk_require_from_base('configurator')
dtk_require_from_base('command_helpers/service_importer')
dtk_require_from_base('command_helpers/test_module_creator')

require 'fileutils'

DEFAULT_COMMIT_MSG = "Initial commit."
PULL_CATALOGS = ["dtkn"]

module DTK::Client
  dtk_require_common_commands('thor/base_command_helper')
  class CommonModule
    dtk_require_common_commands('thor/module/import')
  end

  module ModuleMixin

    REQ_MODULE_ID   = [:service_module_id!, :component_module_id!, :test_module_id!]
    REQ_MODULE_NAME = [:service_module_name!, :component_module_name!, :test_module_name!]

    include PuppetForgeMixin
    include CloneMixin
    include PushToRemoteMixin
    include PullFromRemoteMixin
    include PushCloneChangesMixin
    include EditMixin
    include ReparseMixin
    include PurgeCloneMixin
    include ListDiffsMixin
    include ServiceImporter
    include AccessControlMixin
    include RemotesMixin

    def get_module_type(context_params)
      forwarded_type = context_params.get_forwarded_options() ? context_params.get_forwarded_options()[:module_type] : nil

      if context_params.root_command_name || forwarded_type
        module_type = (context_params.root_command_name||forwarded_type).gsub(/\-/, "_")
      else
        module_type = resolve_module_type
      end

      module_type
    end

    def module_info_about(context_params, about, data_type)
      module_id, component_template_id = context_params.retrieve_arguments([REQ_MODULE_ID, :component_id],method_argument_names)
      module_type = get_module_type(context_params)

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :component_template_id => component_template_id,
        :about => about
      }
      response  = post rest_url("#{module_type}/info_about"), post_body
      data_type = data_type

      response.render_table(data_type) unless options.list?
    end

    def module_info_aux(context_params)
      module_type = get_module_type(context_params)

      if context_params.is_there_identifier?(:assembly)
        response = DTK::Client::ContextRouter.routeTask("assembly", "info", context_params, @conn)
      else
        module_id = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)

        post_body = {
         "#{module_type}_id".to_sym => module_id
        }
        response = post rest_url("#{module_type}/info"), post_body
        response.render_custom_info("module")
      end
    end

    def delete_module_aux(context_params, method_opts = {})
      module_location, modules_path = nil, nil
      module_id = context_params.retrieve_arguments([:option_1!], method_argument_names)

      delete_module_sub_aux(context_params, module_id, method_opts)
    end

    def delete_module_sub_aux(context_params, module_id, method_opts = {})
      version     = options.version
      module_name = get_name_from_id_helper(module_id)
      module_type = get_module_type(context_params)

      # delete all versions
      version = 'delete_all' if method_opts[:delete_all]

      unless (options.force? || method_opts[:force_delete])
        msg = "Are you sure you want to delete module '#{module_name}'"
        msg += " version '#{version}'" if version
        is_go = Console.confirmation_prompt("#{msg}"+"?")
        return nil unless is_go
      end

      post_body = { "#{module_type}_id".to_sym => module_id }
      opts = { :module_name => module_name }

      unless version
        # post_body.merge!(:include_base => true)

        versions_response = post rest_url("#{module_type}/list_versions"), post_body
        return versions_response unless versions_response.ok?

        versions = versions_response.data.first['versions']
        if versions.size > 0
          versions << "all" unless versions.size == 1
          ret_version = Console.confirmation_prompt_multiple_choice("\nSelect version to delete:", versions)
          return unless ret_version
          raise DtkError, "You are not allowed to delete 'base' version while other versions exist!" if ret_version.eql?('base')
          version = ret_version
        else
          raise DtkError, "There are no versions created for #{module_type} '#{module_name}'!"
        end
      end

      if version
        if version.eql?('all')
          # delete only versions (not base)
          post_body.merge!(:all_except_base => true)
          opts.merge!(:all_except_base => true)
        elsif version.eql?('delete_all')
          # this means delete entire module (including all versions + base)
          post_body.merge!(:delete_all_versions => true)
          opts.merge!(:delete_all_versions => true)
        else
          # delete specific version only
          post_body.merge!(:version => version)
          opts.merge!(:version => version)
        end
      end

      response = post(rest_url("#{module_type}/delete"), post_body)
      return response unless response.ok?

      # if we do not provide version, server will calculate the latest version which we can use here
      unless version
        version = response.data(:version)
        opts.merge!(:version => version)
      end

      response =
        if options.purge? || method_opts[:purge]
          purge_clone_aux(module_type.to_sym, opts)
        else
          Helper(:git_repo).unlink_local_clone?(module_type.to_sym, module_name, version)
        end

      return response unless response.ok?

      unless method_opts[:no_error_msg]
        if version && version.eql?('all')
          OsUtil.print("All versions (except base) of '#{module_name}' module have been deleted.", :yellow)
        elsif version && version.eql?('delete_all')
          OsUtil.print("All versions of '#{module_name}' module have been deleted.", :yellow)
        else
          msg = "Module '#{module_name}' "
          if version then msg << "version '#{version}' has been deleted successfully."
          else msg << "has been deleted successfully."; end
          OsUtil.print(msg, :yellow)
        end
      end

      Response::Ok.new()
    end

    def set_attribute_module_aux(context_params)
      if context_params.is_there_identifier?(:attribute)
        mapping = [REQ_MODULE_ID, :attribute_id!, :option_1]
      else
        mapping = [REQ_MODULE_ID, :option_1!, :option_2]
      end

      module_id, attribute_id, value = context_params.retrieve_arguments(mapping, method_argument_names)
      module_type = get_module_type(context_params)

      post_body = {
        :attribute_id => attribute_id,
        :attribute_value => value,
        :attribute_type => module_type,
        "#{module_type}_id".to_sym => module_id
      }

      post rest_url('attribute/set'), post_body
    end

    def push_module_aux(context_params, internal_trigger = false, opts = {})
      module_type = get_module_type(context_params)
      module_id, module_name = context_params.retrieve_arguments([REQ_MODULE_ID, "#{module_type}_name".to_sym], method_argument_names)
      version = options['version']

      module_location = OsUtil.module_location(module_type, module_name, version)

      git_import = opts[:git_import]
      opts.merge!(:update_from_includes => true, :force_parse => true) unless git_import
      opts.merge!(:force => options.force?)
      opts.merge!(:generate_docs => options.docs?)

      reparse_aux(module_location)
      push_clone_changes_aux(module_type.to_sym, module_id, version, options['message'] || DEFAULT_COMMIT_MSG, internal_trigger, opts)
    end

    def create_test_module_aux(context_params)
      test_module_name = context_params.retrieve_arguments([:option_1!], method_argument_names)
      module_type = get_module_type(context_params)

      response = DTK::Client::TestModuleCreator.create_clone(module_type.to_sym, test_module_name)
      return response unless response.ok?

      create_response = import(context_params)

      unless create_response.ok?
        error_msg = create_response['errors'].select { |er| er['message'].include? 'cannot be created since it exists already' }
        if error_msg.empty?
          # If server response is not ok and module does not exist on server, delete cloned module, invoke delete method
          delete(context_params, :force_delete => true, :no_error_msg => true)
        end

        # remove temp directory
        FileUtils.rm_rf("#{response['data']['module_directory']}")

        return create_response
      end
    end

    def import_git_module_aux(context_params)
      CommonModule::Import.new(self, context_params).from_git(context_params.get_forwarded_options()[:internal_trigger])
    end

    def import_module_aux(context_params)
      CommonModule::Import.new(self, context_params).from_file()
    end

    def install_module_aux(context_params, internal_trigger = false)
      create_missing_clone_dirs()
      resolve_direct_access(::DTK::Client::Configurator.check_direct_access)

      remote_module_name, version = context_params.retrieve_arguments([:option_1!, :option_2], method_argument_names)
      forwarded_version           = context_params.get_forwarded_options()['version']
      add_version                 = false
      master_only                 = (options.version? && options.version.eql?('master'))

      version ||= forwarded_version || options.version
      version = nil if version.eql?('master')
      if version
        check_version_format(version)
        add_version = true
      end

      # in case of auto-import via service import, we skip cloning to speed up a process
      skip_cloning  = context_params.get_forwarded_options()['skip_cloning'] if context_params.get_forwarded_options()
      do_not_raise  = context_params.get_forwarded_options()[:do_not_raise] if context_params.get_forwarded_options()
      skip_ainstall = context_params.get_forwarded_options() ? context_params.get_forwarded_options()[:skip_auto_install] : false
      skip_base     = context_params.get_forwarded_options()['skip_base']
      module_type   = get_module_type(context_params)

      # ignore_component_error = context_params.get_forwarded_options()[:ignore_component_error]||options.ignore? if context_params.get_forwarded_options()
      ignore_component_error = context_params.get_forwarded_options().empty? ? options.ignore? : context_params.get_forwarded_options()[:ignore_component_error]
      additional_message     = context_params.get_forwarded_options()[:additional_message] if context_params.get_forwarded_options()

      remote_namespace, local_module_name = get_namespace_and_name(remote_module_name, ':')

      post_body = {
        :remote_module_name => remote_module_name.sub(':', '/'),
        :local_module_name => local_module_name,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }
      post_body.merge!(:do_not_raise => do_not_raise) if do_not_raise
      post_body.merge!(:ignore_component_error => ignore_component_error) if ignore_component_error
      post_body.merge!(:additional_message => additional_message) if additional_message
      post_body.merge!(:skip_auto_install => skip_ainstall) if skip_ainstall

      # we need to install base module version if not installed
      unless skip_base
        master_response = install_base_version_aux?(context_params, post_body, module_type, version)
        # return master_response unless master_response.ok?
        return master_response if !master_response.ok? || master_only

        latest_version = master_response.data(:latest_version)

        unless version
          version = latest_version.eql?('master') ? nil : latest_version
        end

        post_body.merge!(:hard_reset_on_pull_version => true) if version
      end

      if version
        add_version = true
        post_body.merge!(:version => version)
      end

      if clone_dir = Helper(:git_repo).local_clone_dir_exists?(module_type.to_sym, local_module_name, :namespace => remote_namespace, :version => version)
        message = "Module's directory (#{clone_dir}) exists on client. To install this needs to be renamed or removed."
        raise DtkError, message unless ignore_component_error
      end

      response = post rest_url("#{module_type}/import"), post_body

      # when silently installing base version we don't want to print anything
      unless skip_base
        # print permission warnings and then check for other warnings
        are_there_warnings = RemoteDependencyUtil.check_permission_warnings(response)
        are_there_warnings ||= RemoteDependencyUtil.print_dependency_warnings(response, nil, :ignore_permission_warnings => true)

        # prompt to see if user is ready to continue with warnings/errors
        if are_there_warnings
          return false unless Console.confirmation_prompt('Do you still want to proceed with import' + '?')
        end
      end

      # case when we need to import additional components
      if response.ok? && !skip_ainstall && (missing_components = response.data(:missing_module_components))
        required_components = response.data(:required_modules)
        opts = { :do_not_raise => true }
        module_opts = ignore_component_error ? opts.merge(:ignore_component_error => true) : opts.merge(:additional_message => true)
        module_opts.merge!(:update_none => true) if options.update_none?
        module_opts.merge!(:hide_output => true) if skip_base && !master_only

        continue = trigger_module_auto_import(missing_components, required_components, module_opts)
        return unless continue

        print_remote_name = add_version ? "#{remote_module_name}(#{version})" : remote_module_name
        print "Resuming DTK Network import for #{module_type} '#{print_remote_name}' ..." unless skip_base
        # repeat import call for service
        post_body.merge!(opts)
        response = post rest_url("#{module_type}/import"), post_body

        # we set skip cloning since it is already done by import
        puts ' Done' unless skip_base
      end

      return response if !response.ok? || response.data(:does_not_exist)
      module_id, module_name, namespace, repo_url, branch, version = response.data(:module_id, :module_name, :namespace, :repo_url, :workspace_branch, :version)

      if error = response.data(:dsl_parse_error)
        dsl_parsed_message = ServiceImporter.error_message(module_name, error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red)
      end

      unless skip_cloning
        # TODO: should we use instead Helper(:git_repo).create_clone_from_optional_branch
        response = Helper(:git_repo).create_clone_with_branch(module_type.to_sym, module_name, repo_url, branch, version, remote_namespace)
      end

      resolve_missing_components(module_id, module_name, namespace, options.force?) if module_type.to_s.eql?('service_module')
      response
    end

    def install_base_version_aux?(context_params, post_body, module_type, version)
      master_response = post rest_url("#{module_type}/prepare_for_install_module"), post_body
      return master_response unless master_response.ok?

      head_installed     = master_response.data(:head_installed)
      latest_version     = master_response.data(:latest_version)
      remote_module_name = context_params.retrieve_arguments([:option_1!], method_argument_names)

      if version
        versions = master_response.data(:versions)
        raise DtkError, "Module '#{remote_module_name}' version '#{version}' does not exist on repo manager!" unless versions.include?(version)
      end

      base_response = nil
      if !head_installed && !latest_version.eql?('master')
        new_context_params = DTK::Shell::ContextParams.new
        new_context_params.add_context_to_params(module_type, module_type)
        new_context_params.method_arguments = [remote_module_name]
        new_context_params.forward_options('skip_base' => true, 'version' => 'master')
        base_response = install_module_aux(new_context_params)
      end

      return base_response if base_response && (options.version? && options.version.eql?('master'))
      master_response
    end

    def delete_from_catalog_aux(context_params)
      module_type        = get_module_type(context_params)
      remote_module_name = context_params.retrieve_arguments([:option_1!], method_argument_names)
      version            = options.version
      rsa_pub_key        = SSHUtil.rsa_pub_key_content()

      # remote_module_name can be namespace:name or namespace/name
      remote_namespace, remote_module_name = get_namespace_and_name(remote_module_name, ':')

      if version
        check_version_format(version)
      else
        list_post_body = {
          "#{module_type}_id".to_sym => "#{remote_namespace}:#{remote_module_name}",
          :rsa_pub_key => rsa_pub_key,
          :include_base => true
        }
        # versions_response = post rest_url("#{module_type}/list_remote_versions"), list_post_body
        versions_response = post rest_url("#{module_type}/list_remote"), list_post_body
        return versions_response unless versions_response.ok?

        selected_module = versions_response.data.find{ |vr| vr['display_name'].eql?("#{remote_namespace}/#{remote_module_name}") }
        raise DtkError, "Module '#{remote_namespace}/#{remote_module_name}'' does not exist on repo manager!" unless selected_module

        versions = selected_module['versions']
        if versions.size > 2
          versions << "all"
          ret_version = Console.confirmation_prompt_multiple_choice("\nSelect version to delete:", versions)
          return unless ret_version
          raise DtkError, "You are not allowed to delete 'base' version while other versions exist!" if ret_version.eql?('base')
          version = ret_version
        end
      end

      unless options.force? || options.confirmed?
        msg = "Are you sure you want to delete remote #{module_type} '#{remote_namespace.nil? ? '' : remote_namespace + '/'}#{remote_module_name}'"
        msg += " version '#{version}'" if version
        msg += " and all items contained in it"
        return unless Console.confirmation_prompt(msg + '?')
      end

      post_body = {
        :rsa_pub_key             => rsa_pub_key,
        :remote_module_name      => remote_module_name,
        :remote_module_namespace => remote_namespace,
        :force_delete            => options.force?
      }
      post_body.merge!(:version => version) if version

      response = post rest_url("#{module_type}/delete_remote"), post_body
      return response unless response.ok?

      full_module_name, version = response.data(:module_full_name, :version)
      msg = "Module '#{full_module_name}' "
      msg << "version '#{version}'" if version && !version.eql?('master')
      msg << " has been deleted successfully."
      OsUtil.print(msg, :yellow)

      Response::Ok.new()
    end

    def publish_module_aux(context_params)
      module_type = get_module_type(context_params)
      module_id, module_name, input_remote_name = context_params.retrieve_arguments([REQ_MODULE_ID, REQ_MODULE_NAME, :option_1], method_argument_names)

      raise DtkValidationError, "You have to provide version you want to publish!" unless options.version

      unless input_remote_name
        input_remote_name = module_name.gsub(":","/")
        context_params.method_arguments << input_remote_name
      end

      skip_base         = context_params.get_forwarded_options()['skip_base']
      forwarded_version = context_params.get_forwarded_options()['version']

      version = forwarded_version||options.version
      version = nil if version.eql?('master')

      forward_namespace?(module_name, input_remote_name, context_params)

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :remote_component_name => input_remote_name,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content(),
      }

      unless skip_base
        check_response = post rest_url("#{module_type}/check_remote_exist"), post_body
        return check_response unless check_response.ok?

        remote_exist = check_response.data(:remote_exist)
        unless remote_exist
          context_params.forward_options('skip_base' => true, 'version' => 'master')
          resp = publish_module_aux(context_params)
          return resp unless resp.ok?
        end

        context_params.forward_options('do_not_raise_if_exist' => true, 'version' => version)
        create_response = create_new_version_aux(context_params, true)
        return create_response unless create_response.ok?
      end

      post_body.merge!(:version => version) if version
      response = post rest_url("#{module_type}/export"), post_body
      return response unless response.ok?

      unless skip_base
        full_module_name = "#{response.data['remote_repo_namespace']}/#{response.data['remote_repo_name']}"
        DTK::Client::RemoteDependencyUtil.print_dependency_warnings(response, "Module has been successfully published to '#{full_module_name}' version '#{version}'!")
      end

      Response::Ok.new()
    end

    # def publish_module_aux(context_params)
    #   module_type  = get_module_type(context_params)
    #   module_id, module_name, input_remote_name = context_params.retrieve_arguments([REQ_MODULE_ID, REQ_MODULE_NAME, :option_1], method_argument_names)

    #   post_body = {
    #     "#{module_type}_id".to_sym => module_id,
    #     :remote_component_name => input_remote_name,
    #     :rsa_pub_key => SSHUtil.rsa_pub_key_content()
    #   }
    #   if options.version?
    #     post_body.merge!(:version => options.version)
    #   else
    #     post_body.merge!(:use_latest => true)
    #   end

    #   # check if module exist on repo manager and use it to decide if need to push or publish
    #   check_response = post rest_url("#{module_type}/check_remote_exist"), post_body
    #   return check_response unless check_response.ok?

    #   unless options.version?
    #     version = check_response.data(:version)
    #     context_params.forward_options('version' => version)
    #     post_body.merge!(:version => version)
    #   end

    #   # if remote module exist and user call 'publish' we do push-dtkn else we publish it as new module
    #   response_data = check_response['data']
    #   if response_data["remote_exist"]
    #     raise DtkValidationError, "You are not allowed to update #{module_type} versions!" if response_data['frozen']

    #     # if do publish namespace2/module from namespace1/module, forward namespace as option to be used in push_dtkn_module_aux
    #     forward_namespace?(module_name, input_remote_name, context_params)

    #     push_dtkn_module_aux(context_params, true)
    #   else
    #     response = post rest_url("#{module_type}/export"), post_body
    #     return response unless response.ok?

    #     full_module_name = "#{response.data['remote_repo_namespace']}/#{response.data['remote_repo_name']}"

    #     DTK::Client::RemoteDependencyUtil.print_dependency_warnings(response, "Module has been successfully published to '#{full_module_name}'!")
    #     Response::Ok.new()
    #   end
    # end

    def pull_dtkn_aux(context_params)
      module_id, module_name = context_params.retrieve_arguments([REQ_MODULE_ID,REQ_MODULE_NAME,:option_1],method_argument_names)

      catalog      = 'dtkn'
      version      = options.version||context_params.get_forwarded_options()[:version]
      module_type  = get_module_type(context_params)
      skip_recursive_pull = context_params.get_forwarded_options()[:skip_recursive_pull]
      ignore_dependency_merge_conflict = context_params.get_forwarded_options()[:skip_recursive_pull]

      raise DtkValidationError, "You have to provide valid catalog to pull changes from! Valid catalogs: #{PULL_CATALOGS}" unless catalog

      module_location = OsUtil.module_location(resolve_module_type(), module_name, version)

      if catalog.to_s.eql?("dtkn")
        clone_aux(module_type.to_sym, module_id, version, true, true) unless File.directory?(module_location)
        opts = {
          :force               => options.force?,
          :version             => version,
          :remote_namespace    => options.namespace,
          :skip_recursive_pull => skip_recursive_pull,
          :ignore_dependency_merge_conflict => ignore_dependency_merge_conflict
        }

        opts.merge!(:do_not_raise => true) if (context_params.get_forwarded_options()||{})[:do_not_raise]
        response = pull_from_remote_aux(module_type.to_sym, module_id, opts)
        return response unless response.ok?

        push_clone_changes_aux(module_type.to_sym, module_id, version, nil, true, {:update_from_includes => true}) if File.directory?(module_location)
        response.skip_render = true
        response
      else
        raise DtkValidationError, "You have to provide valid catalog to pull changes from! Valid catalogs: #{PULL_CATALOGS}"
      end
    end

    def chmod_module_aux(context_params)
      module_id, permission_selector = context_params.retrieve_arguments([REQ_MODULE_ID, :option_1!], method_argument_names)
      chmod_aux(module_id, permission_selector, options.namespace)
    end

    def make_public_module_aux(context_params)
      module_id = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      chmod_aux(module_id, "o+r", options.namespace, :make_public)
    end

    def make_private_module_aux(context_params)
      module_id = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      chmod_aux(module_id, "o-rwd", options.namespace, :make_private)
    end

    def add_collaborators_module_aux(context_params)
      module_id = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      collaboration_aux(:add, module_id, options.users, options.groups, options.namespace)
    end

    def remove_collaborators_module_aux(context_params)
      module_id = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      collaboration_aux(:remove, module_id, options.users, options.groups, options.namespace)
    end

    def list_collaborators_module_aux(context_params)
      module_id = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      response  = collaboration_list_aux(module_id, options.namespace)
      response.render_table(:module_collaborators)
      response
    end

    def clone_module_aux(context_params, internal_trigger = false)
      module_type      = get_module_type(context_params)
      forward_options  = context_params.get_forwarded_options()
      thor_options     = forward_options.empty? ? options : forward_options
      module_id        = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      module_name      = context_params.retrieve_arguments(["#{module_type}_name".to_sym],method_argument_names)
      version          = thor_options["version"]||options.version
      internal_trigger = true if thor_options['skip_edit']
      clone_aux(module_type.to_sym, module_id, version, internal_trigger, thor_options['omit_output'], :use_latest => true)
    end

    def edit_module_aux(context_params)
      module_type = get_module_type(context_params)
      module_id   = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      module_name = context_params.retrieve_arguments(["#{module_type}_name".to_sym], method_argument_names)
      version     = options.version||context_params.retrieve_arguments([:option_1], method_argument_names)
      edit_dsl    = context_params.get_forwarded_options()[:edit_dsl] if context_params.get_forwarded_options()

      #TODO: cleanup so dont need :base_file_name and get edit_file from server
      opts = {}
      base_file_name = "dtk.model"
      opts.merge!(:edit_file => {:base_file_name => base_file_name}) if edit_dsl
      edit_aux(module_type.to_sym, module_id, module_name, version, opts)
    end

    def push_remote_module_aux(context_params)
      module_id, module_name, remote_name = context_params.retrieve_arguments([REQ_MODULE_ID, REQ_MODULE_NAME, :option_1],method_argument_names)
      version     = options["version"]
      module_type = get_module_type(context_params)

      post_body = {
        "#{module_type}_id".to_sym => module_id
      }

      response      = post rest_url("#{module_type}/info_git_remote"), post_body
      remotes_list  = response.data

      # vital information, abort if it does not exist
      raise DtkError, "There are no registered remotes, aborting action" if remotes_list.empty?

      # check if there is provided remote
      if remote_name
        target_remote = remotes_list.find { |r| remote_name.eql?(r['display_name']) }
        raise DtkError, "Not able to find remote '#{remote_name}'" unless target_remote
      end

      # if only one take it, else raise ambiguous error
      unless target_remote
        if remotes_list.size == 1
          target_remote = remotes_list.first
        else
          remote_names = remotes_list.collect { |r| r['display_name'] }
          raise DtkError, "Call is ambiguous, please provide remote name. Remotes: #{remote_names.join(', ')} "
        end
      end

      # clone if necessry
      module_location = OsUtil.module_location(resolve_module_type(), module_name, version)
      unless File.directory?(module_location)
        response = clone_aux(module_type.to_sym, module_id, version, true, true)
        return response unless response.ok?
      end

      if target_remote['base_git_location']
        OsUtil.print("Pushing local content to remote #{target_remote['base_git_url']} in folder #{target_remote['base_git_location']} ...")
        return push_to_git_remote_location_aux(module_name, module_type.to_sym, version, {
                  :remote_repo_url      => target_remote['base_git_url'],
                  :remote_repo_location => target_remote['base_git_location'],
                  :remote_branch        => 'master',
                  :remote_repo          => "#{target_remote['display_name']}--remote"
               }, options.force?)
      else
        OsUtil.print("Pushing local content to remote #{target_remote['repo_url']} ... ", :yellow)
        return push_to_git_remote_aux(module_name, module_type.to_sym, version, {
                  :remote_repo_url => target_remote['repo_url'],
                  :remote_branch   => 'master',
                  :remote_repo     =>  "#{target_remote['display_name']}--remote"
                },  options.force?)
      end
    end

    def push_dtkn_module_aux(context_params, internal_trigger=false)
      module_id, module_name = context_params.retrieve_arguments([REQ_MODULE_ID, REQ_MODULE_NAME],method_argument_names)
      catalog     = 'dtkn'
      version     = options["version"]||context_params.get_forwarded_thor_option('version')
      module_type = get_module_type(context_params)

      raise DtkValidationError, "You have to provide valid catalog to push changes to! Valid catalogs: #{PushCatalogs}" unless catalog

      module_location = OsUtil.module_location(resolve_module_type(), module_name, version)
      reparse_aux(module_location) unless internal_trigger
      local_namespace, local_module_name = get_namespace_and_name(module_name,':')

      if catalog.to_s.eql?("dtkn")
        module_refs_content = RemoteDependencyUtil.module_ref_content(module_location)
        options_namespace = options["namespace"]||context_params.get_forwarded_thor_option('namespace')
        remote_module_info  = get_remote_module_info_aux(module_type.to_sym, module_id, options_namespace, version, module_refs_content, local_namespace)
        return remote_module_info unless remote_module_info.ok?

        unless File.directory?(module_location)
          response = clone_aux(module_type.to_sym, module_id, version, true, true)

          if(response.nil? || response.ok?)
            reparse_aux(module_location)
            response = push_to_remote_aux(remote_module_info, module_type.to_sym)
          end

          return response
        end

        push_to_remote_aux(remote_module_info, module_type.to_sym, options.force?)
      else
        raise DtkValidationError, "You have to provide valid catalog to push changes to! Valid catalogs: #{PushCatalogs}"
      end
    end

    PushCatalogs = ["origin", "dtkn"]

    def list_diffs_module_aux(context_params)
      module_type = get_module_type(context_params)
      module_id   = context_params.retrieve_arguments([REQ_MODULE_ID],method_argument_names)
      module_name = context_params.retrieve_arguments(["#{module_type}_name".to_sym],method_argument_names)
      version     = options["version"]

      module_location = OsUtil.module_location(module_type, module_name, version)

      # check if there is repository cloned
      if File.directory?(module_location)
        list_diffs_aux(module_type.to_sym, module_id, options.remote?, version)
      else
        if Console.confirmation_prompt("Module '#{module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          response = clone_aux(module_type.to_sym, module_id, version, true)
          # if error return
          unless response.ok?
            return response
          end
        else
          # user choose not to clone needed module
          return
        end
      end
    end

    def list_remote_module_diffs(context_params)
      module_type = get_module_type(context_params)
      module_id   = context_params.retrieve_arguments([REQ_MODULE_ID],method_argument_names)
      list_remote_diffs_aux(module_type.to_sym, module_id)
    end

    def list_versions_aux(context_params)
      module_type  = get_module_type(context_params)
      module_id    = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      include_base = context_params.get_forwarded_options()['include_base']

      post_body = { "#{module_type}_id".to_sym => module_id }
      post_body.merge!(:include_base => include_base) if include_base

      response = post rest_url("#{module_type}/list_versions"), post_body
    end

    def list_remote_versions_aux(context_params)
      module_type  = get_module_type(context_params)
      module_id = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }

      response = post rest_url("#{module_type}/list_remote_versions"), post_body
    end

    def delete_assembly_aux(context_params)
      module_type = get_module_type(context_params)

      module_id, assembly_template_id = context_params.retrieve_arguments([REQ_MODULE_ID,:option_1!], method_argument_names)
      module_name = context_params.retrieve_arguments([:service_module_name],method_argument_names)

      assembly_template_name = (assembly_template_id.to_s =~ /^[0-9]+$/) ? DTK::Client::Assembly.get_assembly_template_name_for_service(assembly_template_id, module_name) : assembly_template_id
      assembly_template_id   = DTK::Client::Assembly.get_assembly_template_id_for_service(assembly_template_id, module_name) unless assembly_template_id.to_s =~ /^[0-9]+$/

      return unless Console.confirmation_prompt("Are you sure you want to delete assembly '#{assembly_template_name||assembly_template_id}'"+'?') unless options.force?

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :assembly_id => assembly_template_id,
        :subtype => :template
      }

      response = post rest_url("#{module_type}/delete_assembly_template"), post_body
      return response unless response.ok?

      module_location = OsUtil.module_location(module_type, module_name)

      if (module_location && assembly_template_name)
        assembly_template_location = "#{module_location}/assemblies/#{assembly_template_name}"
        base_file = "#{module_location}/assemblies/#{assembly_template_name}.dtk.assembly"

        assembly_file_location =
          if File.exists?("#{base_file}.yaml")
            "#{base_file}.yaml"
          elsif File.exists?("#{base_file}.json")
            "#{base_file}.json"
          else
            nil
          end
      end

      FileUtils.rm("#{assembly_file_location}") if assembly_file_location
      if File.directory?(assembly_template_location)
        unless (assembly_template_location.nil? || ("#{module_location}/assemblies/" == assembly_template_location))
          FileUtils.rm_rf("#{assembly_template_location}")
        end
      end
      version = nil
      commit_msg = "Deleting assembly template #{assembly_template_name.to_s}"
      internal_trigger = true
      push_clone_changes_aux(module_type.to_sym, module_id, version, commit_msg, internal_trigger, :skip_cloning => true)

      Response::Ok.new()
    end

    def list_instances_aux(context_params)
      module_type = get_module_type(context_params)
      module_id   = context_params.retrieve_arguments([REQ_MODULE_ID],method_argument_names)

      post_body   = {
        "#{module_type}_id".to_sym => module_id,
      }
      response = post rest_url("#{module_type}/list_instances"), post_body

      # response.render_table(:assembly_template)
      response.render_table(:assembly)
    end

    def fork_aux(context_params)
      module_type = get_module_type(context_params)
      module_id, fork_namespace = context_params.retrieve_arguments([REQ_MODULE_ID, :option_1!], method_argument_names)

      raise DtkValidationError, "Namespace '#{fork_namespace}' contains invalid characters. Valid characters are letters, numbers, dash and underscore." unless fork_namespace.to_s =~ /^[0-9a-zA-Z\_\-]*$/

      module_name = context_params.retrieve_arguments(["#{module_type}_name".to_sym],method_argument_names)
      namespace, name = get_namespace_and_name(module_name,':')

      module_location = OsUtil.module_location(module_type, module_name, nil)
      unless File.directory?(module_location)
        if Console.confirmation_prompt("Module '#{module_name}' has not been cloned. Would you like to clone module now"+'?')
          response = clone_aux(module_type.to_sym, module_id, nil, true)
          return response unless response.ok?
        end
      end

      response = Helper(:git_repo).cp_r_to_new_namespace(module_type, name, namespace, fork_namespace)
      return response unless response.ok?

      new_context_params = DTK::Shell::ContextParams.new
      new_context_params.add_context_to_params(module_type, module_type)
      new_context_params.method_arguments = ["#{fork_namespace}:#{name}"]

      create_response = DTK::Client::ContextRouter.routeTask(module_type, "import", new_context_params, @conn)
      unless create_response.ok?
        FileUtils.rm_rf("#{response['data']['module_directory']}")
        return create_response
      end

      Response::Ok.new()
    end

    def create_new_version_aux(context_params, internal_trigger = false)
      module_type = get_module_type(context_params)
      module_id, version = context_params.retrieve_arguments([REQ_MODULE_ID, :option_1!], method_argument_names)

      version = (context_params.get_forwarded_options()['version'] || options.version) if internal_trigger

      module_name           = context_params.retrieve_arguments(["#{module_type}_name".to_sym],method_argument_names)
      namespace, name       = get_namespace_and_name(module_name,':')
      do_not_raise_if_exist = context_params.get_forwarded_options()['do_not_raise_if_exist']

      module_location = OsUtil.module_location(module_type, module_name, nil)
      unless File.directory?(module_location)
        if Console.confirmation_prompt("Module '#{module_name}' has not been cloned. Would you like to clone module now"+'?')
          response = clone_aux(module_type.to_sym, module_id, nil, true)
          return response unless response.ok?
        end
      end

      opts = {:do_not_raise_if_exist => do_not_raise_if_exist} if do_not_raise_if_exist
      m_name, m_namespace, repo_url, branch, not_ok_response = workspace_branch_info(module_type, module_id, nil)
      resp = Helper(:git_repo).create_new_version(module_type, branch, name, namespace, version, repo_url, opts||{})

      post_body = get_workspace_branch_info_post_body(module_type, module_id, version)
      post_body.merge!(:do_not_raise_if_exist => do_not_raise_if_exist) if do_not_raise_if_exist
      create_response = post(rest_url("#{module_type}/create_new_version"), post_body)

      unless create_response.ok?
        FileUtils.rm_rf("#{resp['module_directory']}") unless resp['exist_already']
        return create_response
      end

      if version_exist = create_response.data(:version_exist)
        return create_response if do_not_raise_if_exist
      end

      if error = create_response.data(:dsl_parse_error)
        dsl_parsed_message = ServiceImporter.error_message(module_name, error)
        DTK::Client::OsUtil.print(dsl_parsed_message, :red)
      end

      if external_dependencies = create_response.data(:external_dependencies)
        print_dependencies(external_dependencies)
      end

      if component_module_refs = create_response.data(:component_module_refs)
        print_using_dependencies(component_module_refs)
      end

      Response::Ok.new()
    end

    def print_ambiguous(ambiguous)
    end

    def forward_namespace?(module_name, input_remote_name, context_params)
      return unless input_remote_name
      local_namespace, local_name   = get_namespace_and_name(module_name,':')
      remote_namespace, remote_name = get_namespace_and_name(input_remote_name,'/')
      context_params.forward_options('namespace' => remote_namespace) unless local_namespace.eql?(remote_namespace)
    end

    def print_dependencies(dependencies)
      ambiguous        = dependencies["ambiguous"]||[]
      amb_sorted       = ambiguous.map { |k,v| "#{k.split('/').last} (#{v.join(', ')})" }
      inconsistent     = dependencies["inconsistent"]||[]
      possibly_missing = dependencies["possibly_missing"]||[]

      OsUtil.print("There are inconsistent module dependencies mentioned in dtk.model.yaml: #{inconsistent.join(', ')}", :red) unless inconsistent.empty?
      OsUtil.print("There are missing module dependencies mentioned in dtk.model.yaml: #{possibly_missing.join(', ')}", :yellow) unless possibly_missing.empty?
      OsUtil.print("There are ambiguous module dependencies mentioned in dtk.model.yaml: '#{amb_sorted.join(', ')}'. One of the namespaces should be selected by editing the module_refs file", :yellow) if ambiguous && !ambiguous.empty?
    end

    def print_using_dependencies(component_refs)
      unless component_refs.empty?
        puts 'Using component modules:'
        names = []
        component_refs.values.each do |cmp_ref|
          version = cmp_ref['version_info']
          name    = "#{cmp_ref['namespace_info']}:#{cmp_ref['module_name']}"
          name << "(#{version})" if version
          names << name
        end
        names.sort.each do |name|
          puts "  #{name}"
        end
      end
    end

    def check_version_format(version)
      unless version.match(/\A\d{1,2}\.\d{1,2}\.\d{1,2}\Z/)
        raise DtkValidationError, "Version has an illegal value '#{version}', format needed: '##.##.##'"
      end
    end

  end
end