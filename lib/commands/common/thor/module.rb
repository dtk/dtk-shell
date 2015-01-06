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
dtk_require_from_base('configurator')
dtk_require_from_base('command_helpers/service_importer')
dtk_require_from_base('command_helpers/test_module_creator')

require 'fileutils'

DEFAULT_COMMIT_MSG = "Initial commit."
PULL_CATALOGS = ["dtkn"]

module DTK::Client
  module ModuleMixin
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

    REQ_MODULE_ID   = [:service_module_id!, :component_module_id!, :test_module_id!]
    REQ_MODULE_NAME = [:service_module_name!, :component_module_name!, :test_module_name!]

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

    def delete_module_aux(context_params, method_opts={})
      module_location, modules_path = nil, nil
      module_id = context_params.retrieve_arguments([:option_1!], method_argument_names)

      delete_module_sub_aux(context_params, module_id, method_opts)
    end

    def delete_module_sub_aux(context_params, module_id, method_opts={})
      # ModuleUtil.check_format!(module_id)
      version = options.version
      module_name = get_name_from_id_helper(module_id)
      module_type = get_module_type(context_params)

      unless (options.force? || method_opts[:force_delete])
        is_go = Console.confirmation_prompt("Are you sure you want to delete module '#{module_name}'"+"?")
        return nil unless is_go
      end

      response =
        if options.purge? || method_opts[:purge]
          opts = {:module_name => module_name}
          if version then opts.merge!(:version => version)
          else opts.merge!(:delete_all_versions => true)
          end
          purge_clone_aux(module_type.to_sym, opts)
        else
          Helper(:git_repo).unlink_local_clone?(module_type.to_sym, module_name, version)
        end

      return response unless response.ok?

      post_body = {
       "#{module_type}_id".to_sym => module_id
      }
      action = (version ? "delete_version" : "delete")
      post_body[:version] = version if version

      response = post(rest_url("#{module_type}/#{action}"), post_body)
      return response unless response.ok?

      unless method_opts[:no_error_msg]
        msg = "Module '#{module_name}' "
        if version then msg << "version #{version} has been deleted"
        else  msg << "has been deleted"; end
        OsUtil.print(msg, :yellow)
      end

      Response::Ok.new()
    end

    def set_attribute_module_aux(context_params)
      if context_params.is_there_identifier?(:attribute)
        mapping = [REQ_MODULE_ID,:attribute_id!, :option_1]
      else
        mapping = [REQ_MODULE_ID,:option_1!,:option_2]
      end

      module_id, attribute_id, value = context_params.retrieve_arguments(mapping, method_argument_names)
      module_type = get_module_type(context_params)

      post_body = {
        :attribute_id => attribute_id,
        :attribute_value => value,
        :attribute_type => module_type,
        "#{module_type}_id".to_sym => module_id
      }

      post rest_url("attribute/set"), post_body
    end

    def push_module_aux(context_params, internal_trigger=false, opts={})
      module_type = get_module_type(context_params)
      module_id, module_name = context_params.retrieve_arguments([REQ_MODULE_ID, "#{module_type}_name".to_sym],method_argument_names)
      version = options["version"]

      module_location = OsUtil.module_location(module_type, module_name, version)

      git_import = opts[:git_import]
      opts.merge!(:update_from_includes => true, :force_parse => true) unless git_import

      reparse_aux(module_location)
      push_clone_changes_aux(module_type.to_sym, module_id, version, options["message"]||DEFAULT_COMMIT_MSG, internal_trigger, opts)
     end

    def create_test_module_aux(context_params)
      test_module_name = context_params.retrieve_arguments([:option_1!], method_argument_names)
      module_type = get_module_type(context_params)

      response = DTK::Client::TestModuleCreator.create_clone(module_type.to_sym, test_module_name)
      return response unless response.ok?

      create_response = import(context_params)

      unless create_response.ok?
        error_msg = create_response['errors'].select { |er| er['message'].include? "cannot be created since it exists already" }
        if error_msg.empty?
          # If server response is not ok and module does not exist on server, delete cloned module, invoke delete method
          delete(context_params,:force_delete => true, :no_error_msg => true)
        end

        # remove temp directory
        FileUtils.rm_rf("#{response['data']['module_directory']}")

        return create_response
      end
    end

     def import_git_module_aux(context_params)
      git_repo_url, module_name = context_params.retrieve_arguments([:option_1!, :option_2!],method_argument_names)
      module_type  = get_module_type(context_params)

      thor_options = Hash.new
      namespace, local_module_name = get_namespace_and_name(module_name, ModuleUtil::NAMESPACE_SEPERATOR)

      unless namespace
        resp = post rest_url("namespace/default_namespace_name")
        namespace = resp.data
        thor_options[:default_namespace] = namespace
      end
      # Create component module from user's input git repo
      opts = {
        :namespace => namespace,
        :branch  => options['branch']
      }
      response = Helper(:git_repo).create_clone_from_optional_branch(module_type.to_sym, local_module_name, git_repo_url, opts)

      # Raise error if git repository is invalid
      # raise DtkError,"Git repository URL '#{git_repo_url}' is invalid." unless response.ok?
      return response unless response.ok?

      # Remove .git directory to rid of git pointing to user's github
      FileUtils.rm_rf("#{response['data']['module_directory']}/.git")

      # context_params.forward_options({:git_import => true})
      thor_options[:git_import] = true
      context_params.forward_options(thor_options)
      # Reuse module create method to create module from local component_module
      create_response = import(context_params)

      if create_response.ok?
        if external_dependencies = create_response.data(:external_dependencies)
          inconsistent = external_dependencies["inconsistent"]||[]
          possibly_missing = external_dependencies["possibly_missing"]||[]
          ambiguous = external_dependencies["ambiguous"]||[]
          amb_sorted = ambiguous.map { |k,v| "#{k.split('/').last} (#{v.join(', ')})" }
          OsUtil.print("There are inconsistent module dependencies mentioned in the git repo: #{inconsistent.join(', ')}", :red) unless inconsistent.empty?
          OsUtil.print("There are missing module dependencies mentioned in the git repo: #{possibly_missing.join(', ')}", :yellow) unless possibly_missing.empty?
          OsUtil.print("There are ambiguous module dependencies mentioned in the git repo: '#{amb_sorted.join(', ')}'. One of the namespaces should be selected by editing the module_refs file", :yellow) if ambiguous && !ambiguous.empty?
        end
      else
        delete_dir        = namespace.nil? ? local_module_name : "#{namespace}/#{local_module_name}"
        full_module_name  = create_response.data[:full_module_name]
        local_module_name = full_module_name.nil? ? delete_dir : full_module_name
        delete_module_sub_aux(context_params, local_module_name, :force_delete => true, :no_error_msg => true, :purge => true)
        return create_response
      end

      Response::Ok.new()
    end
    def import_module_aux(context_params)
      if context_params.get_forwarded_options()
        git_import = context_params.get_forwarded_options()[:git_import]
        default_namespace = context_params.get_forwarded_options()[:default_namespace]
      end

      if git_import
        return import_module_aux__new(context_params)
      end

      name_option = git_import ? :option_2! : :option_1!
      module_name = context_params.retrieve_arguments([name_option],method_argument_names)
      module_type = get_module_type(context_params)
      version     = options["version"]
      opts        = {}

      namespace, local_module_name = get_namespace_and_name(module_name, ModuleUtil::NAMESPACE_SEPERATOR)
      namespace = default_namespace if default_namespace && namespace.nil?

      # first check that there is a directory there and it is not already a git repo, and it ha appropriate content
      response = Helper(:git_repo).check_local_dir_exists_with_content(module_type.to_sym, local_module_name, nil, namespace)
      return response unless response.ok?
      module_directory = response.data(:module_directory)

      #check for yaml/json parsing errors before import
      reparse_aux(module_directory)

      # first make call to server to create an empty repo
      response = post rest_url("#{module_type}/create"), { :module_name => local_module_name, :module_namespace => namespace }
      return response unless response.ok?

      repo_url,repo_id,module_id,branch,new_module_name = response.data(:repo_url,:repo_id,:module_id,:workspace_branch,:full_module_name)
      response = Helper(:git_repo).rename_and_initialize_clone_and_push(module_type.to_sym, local_module_name, new_module_name, branch, repo_url, module_directory)
      return response unless (response && response.ok?)

      repo_obj,commit_sha = response.data(:repo_obj, :commit_sha)
      module_final_dir = repo_obj.repo_dir
      old_dir = response.data[:old_dir]

      post_body = {
        :repo_id    => repo_id,
        :commit_sha => commit_sha,
        :commit_dsl => true,
        :scaffold_if_no_dsl => true,
        "#{module_type}_id".to_sym => module_id
      }

      response = post(rest_url("#{module_type}/update_from_initial_create"),post_body)

      unless response.ok?
        response.set_data_hash({ :full_module_name => new_module_name })
        # remove new directory and leave the old one if import without namespace failed
        if old_dir and (old_dir != module_final_dir)
          FileUtils.rm_rf(module_final_dir) unless (namespace && git_import)
        end
        return response
      end

      # since we are creating module_refs file on server, we need to pull changes first and then push
      dsl_updated_info = response.data(:dsl_updated_info)
      if dsl_updated_info and !dsl_updated_info.empty?
        DTK::Client::OsUtil.print("A module_refs.yaml file has been created for you, located at #{module_final_dir}",:yellow)

        module_name,module_namespace,repo_url,branch,not_ok_response = workspace_branch_info(module_type,module_id,version)
        return not_ok_response if not_ok_response

        new_commit_sha = dsl_updated_info[:commit_sha]
        unless new_commit_sha and new_commit_sha == commit_sha
          opts_pull = {:local_branch => branch,:namespace => module_namespace}
          resp = Helper(:git_repo).pull_changes(module_type,module_name,opts_pull)
          return resp unless resp.ok?
        end
      end

      external_dependencies = response.data(:external_dependencies)
      dsl_created_info = response.data(:dsl_created_info)

      if external_dependencies
        ambiguous = external_dependencies['ambiguous']||[]
        possibly_missing = external_dependencies["possibly_missing"]||[]
        opts.merge!(:set_parsed_false => true, :skip_module_ref_update => true) unless ambiguous.empty? && possibly_missing.empty?
      end

      if dsl_created_info and !dsl_created_info.empty?
        msg = "A #{dsl_created_info["path"]} file has been created for you, located at #{module_final_dir}"
        DTK::Client::OsUtil.print(msg,:yellow)
        resp = Helper(:git_repo).add_file(repo_obj, dsl_created_info["path"], dsl_created_info["content"], msg)
        return resp unless resp.ok?
      end

      # TODO: what is purpose of pushing again
      # we push clone changes anyway, user can change and push again
      # context_params.add_context_to_params(module_name, :"component-module", module_id)
      context_params.add_context_to_params(local_module_name, module_type.to_s.gsub!(/\_/,'-').to_sym, module_id)
      opts.merge!(:git_import => true) if git_import
      response = push_module_aux(context_params, true, opts)

      unless response.ok?
        # remove new directory and leave the old one if import without namespace failed
        if old_dir and (old_dir != module_final_dir)
          FileUtils.rm_rf(module_final_dir) unless (namespace && git_import)
        end
        return response
      end

      # remove source directory if no errors while importing
      if old_dir and (old_dir != module_final_dir)
        FileUtils.rm_rf(old_dir) unless (namespace && git_import)
      end

      if git_import
        response[:module_id] = module_id
        response.add_data_value!(:external_dependencies, external_dependencies) if external_dependencies
      else
        if external_dependencies
          possibly_missing = external_dependencies["possibly_missing"]||[]
          ambiguous = external_dependencies["ambiguous"]||[]
          amb_sorted = ambiguous.map { |k,v| "#{k.split('/').last} (#{v.join(', ')})" }
          OsUtil.print("There are missing module dependencies in dtk.model.yaml includes: #{possibly_missing.join(', ')}", :yellow) unless possibly_missing.empty?
          OsUtil.print("There are ambiguous module dependencies in dtk.model.yaml includes: '#{amb_sorted.join(', ')}'. One of the namespaces should be selected by editing the module_refs file", :yellow) unless ambiguous.empty?
        end
        # if not git-import and user do import from default directory (e.g. import ntp - without namespace) print message
        # module directory moved from (~/dtk/component_module/<module_name>) to (~/dtk/component_module/<default_namespace>/<module_name>)
        DTK::Client::OsUtil.print("Module '#{new_module_name}' has been created and module directory moved to #{module_final_dir}",:yellow) unless namespace
      end

      response
    end

    def import_module_aux__new(context_params)
      if context_params.get_forwarded_options()
        git_import  = context_params.get_forwarded_options()[:git_import]
        default_namespace = context_params.get_forwarded_options()[:default_namespace]
      end

      name_option = git_import ? :option_2! : :option_1!
      module_name = context_params.retrieve_arguments([name_option],method_argument_names)
      module_type = get_module_type(context_params)
      version     = options["version"]
      opts        = {}

      namespace, local_module_name = get_namespace_and_name(module_name, ModuleUtil::NAMESPACE_SEPERATOR)
      namespace = default_namespace if default_namespace && namespace.nil?

      # first check that there is a directory there and it is not already a git repo, and it ha appropriate content
      response = Helper(:git_repo).check_local_dir_exists_with_content(module_type.to_sym, local_module_name, nil, namespace)
      return response unless response.ok?
      module_directory = response.data(:module_directory)

      #check for yaml/json parsing errors before import
      reparse_aux(module_directory)

      # first make call to server to create an empty repo
      response = post rest_url("#{module_type}/create"), { :module_name => local_module_name, :module_namespace => namespace }
      return response unless response.ok?

      repo_url,repo_id,module_id,branch,new_module_name = response.data(:repo_url,:repo_id,:module_id,:workspace_branch,:full_module_name)
      response = Helper(:git_repo).rename_and_initialize_clone_and_push(module_type.to_sym, local_module_name, new_module_name, branch, repo_url, module_directory)
      return response unless (response && response.ok?)

      repo_obj,commit_sha = response.data(:repo_obj, :commit_sha)
      module_final_dir    = repo_obj.repo_dir
      old_dir             = response.data[:old_dir]

      post_body = {
        :repo_id    => repo_id,
        :commit_sha => commit_sha,
        :commit_dsl => true,
        :scaffold_if_no_dsl => true,
        "#{module_type}_id".to_sym => module_id
      }

      post_body.merge!(:git_import => true) if git_import
      response = post(rest_url("#{module_type}/update_from_initial_create"),post_body)

      unless response.ok?
        response.set_data_hash({ :full_module_name => new_module_name })
        # remove new directory and leave the old one if import without namespace failed
        if old_dir and (old_dir != module_final_dir)
          FileUtils.rm_rf(module_final_dir) unless (namespace && git_import)
        end
        return response
      end

      dsl_updated_info      = response.data(:dsl_updated_info)
      external_dependencies = response.data(:external_dependencies)
      dsl_created_info      = response.data(:dsl_created_info)

      DTK::Client::OsUtil.print("A module_refs.yaml file has been created for you, located at #{module_final_dir}", :yellow) if dsl_updated_info && !dsl_updated_info.empty?
      DTK::Client::OsUtil.print("A #{dsl_created_info["path"]} file has been created for you, located at #{module_final_dir}", :yellow) if dsl_created_info && !dsl_created_info.empty?

      module_name,module_namespace,repo_url,branch,not_ok_response = workspace_branch_info(module_type,module_id,version)
      return not_ok_response if not_ok_response

      opts_pull = {:local_branch => branch,:namespace => module_namespace}
      resp      = Helper(:git_repo).pull_changes(module_type,module_name,opts_pull)
      return resp unless resp.ok?

      if external_dependencies
        ambiguous = external_dependencies['ambiguous']||[]
        possibly_missing = external_dependencies["possibly_missing"]||[]
        opts.merge!(:set_parsed_false => true, :skip_module_ref_update => true) unless ambiguous.empty? && possibly_missing.empty?
      end

      # remove source directory if no errors while importing
      if old_dir and (old_dir != module_final_dir)
        FileUtils.rm_rf(old_dir) unless (namespace && git_import)
      end

      if git_import
        response[:module_id] = module_id
        response.add_data_value!(:external_dependencies, external_dependencies) if external_dependencies
      else
        if external_dependencies
          possibly_missing = external_dependencies["possibly_missing"]||[]
          ambiguous = external_dependencies["ambiguous"]||[]
          amb_sorted = ambiguous.map { |k,v| "#{k.split('/').last} (#{v.join(', ')})" }
          OsUtil.print("There are missing module dependencies in dtk.model.yaml includes: #{possibly_missing.join(', ')}", :yellow) unless possibly_missing.empty?
          OsUtil.print("There are ambiguous module dependencies in dtk.model.yaml includes: '#{amb_sorted.join(', ')}'. One of the namespaces should be selected by editing the module_refs file", :yellow) unless ambiguous.empty?
        end
        # if not git-import and user do import from default directory (e.g. import ntp - without namespace) print message
        # module directory moved from (~/dtk/component_module/<module_name>) to (~/dtk/component_module/<default_namespace>/<module_name>)
        DTK::Client::OsUtil.print("Module '#{new_module_name}' has been created and module directory moved to #{module_final_dir}",:yellow) unless namespace
      end

      response
    end

    def install_module_aux(context_params)
      create_missing_clone_dirs()
      resolve_direct_access(::DTK::Client::Configurator.check_direct_access)
      remote_module_name, version = context_params.retrieve_arguments([:option_1!, :option_2],method_argument_names)
      # in case of auto-import via service import, we skip cloning to speed up a process
      skip_cloning = context_params.get_forwarded_options()['skip_cloning'] if context_params.get_forwarded_options()
      do_not_raise = context_params.get_forwarded_options()[:do_not_raise] if context_params.get_forwarded_options()
      skip_ainstall = context_params.get_forwarded_options() ? context_params.get_forwarded_options()[:skip_auto_install] : false
      module_type  = get_module_type(context_params)

      # ignore_component_error = context_params.get_forwarded_options()[:ignore_component_error]||options.ignore? if context_params.get_forwarded_options()
      ignore_component_error = context_params.get_forwarded_options() ? context_params.get_forwarded_options()[:ignore_component_error] : options.ignore?
      additional_message     = context_params.get_forwarded_options()[:additional_message] if context_params.get_forwarded_options()

      remote_namespace, local_module_name = get_namespace_and_name(remote_module_name,':')

      if clone_dir = Helper(:git_repo).local_clone_dir_exists?(module_type.to_sym, local_module_name, :namespace => remote_namespace, :version => version)
        message = "Module's directory (#{clone_dir}) exists on client. To install this needs to be renamed or removed"
        message += ". To ignore this conflict and use existing component module please use -i switch (install REMOTE-SERVICE-NAME -i)." if additional_message

        raise DtkError, message unless ignore_component_error
      end

      post_body = {
        :remote_module_name => remote_module_name.sub(':','/'),
        :local_module_name => local_module_name,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }
      post_body.merge!(:do_not_raise => do_not_raise) if do_not_raise
      post_body.merge!(:ignore_component_error => ignore_component_error) if ignore_component_error
      post_body.merge!(:additional_message => additional_message) if additional_message

      response = post rest_url("#{module_type}/import"), post_body
      are_there_warnings = RemoteDependencyUtil.print_dependency_warnings(response)

      # prompt to see if user is ready to continue with warnings/errors
      if are_there_warnings
        return false unless Console.confirmation_prompt("Do you still want to proceed with import"+'?')
      end

      # case when we need to import additional components
      if (response.ok? && !skip_ainstall && (missing_components = response.data(:missing_module_components)))
        required_components = response.data(:required_modules)
        opts = {:do_not_raise=>true}
        module_opts = ignore_component_error ? opts.merge(:ignore_component_error => true) : opts.merge(:additional_message=>true)

        continue = trigger_module_auto_import(missing_components, required_components, module_opts)
        return unless continue

        print "Resuming DTK Network import for #{module_type} '#{remote_module_name}' ..."
        # repeat import call for service
        post_body.merge!(opts)
        response = post rest_url("#{module_type}/import"), post_body

        # we set skip cloning since it is already done by import
        puts " Done"
      end

      return response if(!response.ok? || response.data(:does_not_exist))
      # module_name,repo_url,branch,version = response.data(:module_name, :repo_url, :workspace_branch, :version)
      module_id, module_name, namespace, repo_url, branch, version = response.data(:module_id, :module_name, :namespace, :repo_url, :workspace_branch, :version)

      if error = response.data(:dsl_parsed_info)
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

    def delete_from_catalog_aux(context_params)
      module_type        = get_module_type(context_params)
      remote_module_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      # for service_module we are doing this on server side
      remote_namespace, remote_module_name = get_namespace_and_name(remote_module_name,'/') unless module_type.eql?('service_module')

      unless options.force?
        return unless Console.confirmation_prompt("Are you sure you want to delete remote #{module_type} '#{remote_namespace.nil? ? '' : remote_namespace+'/'}#{remote_module_name}' and all items contained in it"+'?')
      end

      post_body = {
        :rsa_pub_key             => SSHUtil.rsa_pub_key_content(),
        :remote_module_name      => remote_module_name,
        :remote_module_namespace => remote_namespace
      }

      post rest_url("#{module_type}/delete_remote"), post_body
    end

    def publish_module_aux(context_params)
      module_type  = get_module_type(context_params)
      module_id, input_remote_name = context_params.retrieve_arguments([REQ_MODULE_ID, :option_1],method_argument_names)

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :remote_component_name => input_remote_name,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }

      response = post rest_url("#{module_type}/export"), post_body
      return response unless response.ok?

      full_module_name = "#{response.data['remote_repo_namespace']}/#{response.data['remote_repo_name']}"

      DTK::Client::RemoteDependencyUtil.print_dependency_warnings(response, "Module has been successfully published to '#{full_module_name}'!")
      Response::Ok.new()
    end

    def pull_dtkn_aux(context_params)
      module_id, module_name = context_params.retrieve_arguments([REQ_MODULE_ID,REQ_MODULE_NAME,:option_1],method_argument_names)

      catalog      = 'dtkn'
      version      = options["version"]
      module_type  = get_module_type(context_params)
      skip_recursive_pull = context_params.get_forwarded_options()[:skip_recursive_pull]

      raise DtkValidationError, "You have to provide valid catalog to pull changes from! Valid catalogs: #{PULL_CATALOGS}" unless catalog

      module_location = OsUtil.module_location(resolve_module_type(), module_name, version)

      if catalog.to_s.eql?("dtkn")
        clone_aux(module_type.to_sym, module_id, version, true, true) unless File.directory?(module_location)
        opts = {:version => version, :remote_namespace => options.namespace, :skip_recursive_pull => skip_recursive_pull}

        response = pull_from_remote_aux(module_type.to_sym, module_id, opts)
        return response unless response.ok?

        push_clone_changes_aux(module_type.to_sym, module_id, version, nil, true) if File.directory?(module_location)
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
      chmod_aux(module_id, "o+r", options.namespace)
    end

    def make_private_module_aux(context_params)
      module_id = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      chmod_aux(module_id, "o-rwd", options.namespace)
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

    def clone_module_aux(context_params, internal_trigger=false)
      module_type      = get_module_type(context_params)
      thor_options     = context_params.get_forwarded_options() || options
      module_id        = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)
      module_name      = context_params.retrieve_arguments(["#{module_type}_name".to_sym],method_argument_names)
      version          = thor_options["version"]
      internal_trigger = true if thor_options['skip_edit']

      module_location = OsUtil.module_location(module_type, module_name, version)

      raise DTK::Client::DtkValidationError, "#{module_type.gsub('_',' ').capitalize} '#{module_name}#{version && "-#{version}"}' already cloned!" if File.directory?(module_location)
      clone_aux(module_type.to_sym, module_id, version, internal_trigger, thor_options['omit_output'])
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

    def push_dtkn_module_aux(context_params, internal_trigger=false)
      module_id, module_name = context_params.retrieve_arguments([REQ_MODULE_ID, REQ_MODULE_NAME],method_argument_names)
      catalog     = 'dtkn'
      version     = options["version"]
      module_type = get_module_type(context_params)

      raise DtkValidationError, "You have to provide valid catalog to push changes to! Valid catalogs: #{PushCatalogs}" unless catalog

      module_location = OsUtil.module_location(resolve_module_type(), module_name, version)
      reparse_aux(module_location) unless internal_trigger
      local_namespace, local_module_name = get_namespace_and_name(module_name,':')

#      if catalog.to_s.eql?("origin")
#        push_clone_changes_aux(:component_module,component_module_id,version,options["message"]||DEFAULT_COMMIT_MSG,internal_trigger)
      if catalog.to_s.eql?("dtkn")
        module_refs_content = RemoteDependencyUtil.module_ref_content(module_location) if module_type == :service_module
        remote_module_info  = get_remote_module_info_aux(module_type.to_sym, module_id, options["namespace"], version, module_refs_content, local_namespace)
        return remote_module_info unless remote_module_info.ok?

        unless File.directory?(module_location)
          response = clone_aux(module_type.to_sym, module_id, version, true, true)

          if(response.nil? || response.ok?)
            reparse_aux(module_location)
            response = push_to_remote_aux(remote_module_info, module_type.to_sym)
          end

          return response
        end

        push_to_remote_aux(remote_module_info, module_type.to_sym)
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

        # Aldin: could not find better solution, leaving as is for now
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

    def print_ambiguous(ambiguous)
    end

  end
end
