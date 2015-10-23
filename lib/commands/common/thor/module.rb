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

      post_body = {
       "#{module_type}_id".to_sym => module_id
      }
      action = (version ? "delete_version" : "delete")
      post_body[:version] = version if version

      response = post(rest_url("#{module_type}/#{action}"), post_body)
      return response unless response.ok?

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

      unless method_opts[:no_error_msg]
        msg = "Module '#{module_name}' "
        if version then msg << "version #{version} has been deleted"
        else msg << "has been deleted"; end
        OsUtil.print(msg, :yellow)
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

    def install_module_aux(context_params)
      create_missing_clone_dirs()
      resolve_direct_access(::DTK::Client::Configurator.check_direct_access)
      remote_module_name, version = context_params.retrieve_arguments([:option_1!, :option_2], method_argument_names)
      # in case of auto-import via service import, we skip cloning to speed up a process
      skip_cloning = context_params.get_forwarded_options()['skip_cloning'] if context_params.get_forwarded_options()
      do_not_raise = context_params.get_forwarded_options()[:do_not_raise] if context_params.get_forwarded_options()
      skip_ainstall = context_params.get_forwarded_options() ? context_params.get_forwarded_options()[:skip_auto_install] : false
      module_type  = get_module_type(context_params)

      # ignore_component_error = context_params.get_forwarded_options()[:ignore_component_error]||options.ignore? if context_params.get_forwarded_options()
      ignore_component_error = context_params.get_forwarded_options().empty? ? options.ignore? : context_params.get_forwarded_options()[:ignore_component_error]
      additional_message     = context_params.get_forwarded_options()[:additional_message] if context_params.get_forwarded_options()

      remote_namespace, local_module_name = get_namespace_and_name(remote_module_name, ':')

      if clone_dir = Helper(:git_repo).local_clone_dir_exists?(module_type.to_sym, local_module_name, :namespace => remote_namespace, :version => version)
        message = "Module's directory (#{clone_dir}) exists on client. To install this needs to be renamed or removed."
        # message += '. To ignore this conflict and use existing component module please use -i switch (install REMOTE-SERVICE-NAME -i).' if additional_message

        raise DtkError, message unless ignore_component_error
      end

      post_body = {
        :remote_module_name => remote_module_name.sub(':', '/'),
        :local_module_name => local_module_name,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }
      post_body.merge!(:do_not_raise => do_not_raise) if do_not_raise
      post_body.merge!(:ignore_component_error => ignore_component_error) if ignore_component_error
      post_body.merge!(:additional_message => additional_message) if additional_message
      post_body.merge!(:skip_auto_install => skip_ainstall) if skip_ainstall

      response = post rest_url("#{module_type}/import"), post_body

      # print permission warnings and then check for other warnings
      are_there_warnings = RemoteDependencyUtil.check_permission_warnings(response)
      are_there_warnings ||= RemoteDependencyUtil.print_dependency_warnings(response, nil, :ignore_permission_warnings => true)

      # prompt to see if user is ready to continue with warnings/errors
      if are_there_warnings
        return false unless Console.confirmation_prompt('Do you still want to proceed with import' + '?')
      end

      # case when we need to import additional components
      if response.ok? && !skip_ainstall && (missing_components = response.data(:missing_module_components))
        required_components = response.data(:required_modules)
        opts = { :do_not_raise => true }
        module_opts = ignore_component_error ? opts.merge(:ignore_component_error => true) : opts.merge(:additional_message => true)
        module_opts.merge!(:update_none => true) if options.update_none?

        continue = trigger_module_auto_import(missing_components, required_components, module_opts)
        return unless continue

        print "Resuming DTK Network import for #{module_type} '#{remote_module_name}' ..."
        # repeat import call for service
        post_body.merge!(opts)
        response = post rest_url("#{module_type}/import"), post_body

        # we set skip cloning since it is already done by import
        puts ' Done'
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

    def delete_from_catalog_aux(context_params)
      module_type        = get_module_type(context_params)
      remote_module_name = context_params.retrieve_arguments([:option_1!], method_argument_names)

      # remote_module_name can be namespace:name or namespace/name
      remote_namespace, remote_module_name = get_namespace_and_name(remote_module_name, ':')

      unless options.force? || options.confirmed?
        return unless Console.confirmation_prompt("Are you sure you want to delete remote #{module_type} '#{remote_namespace.nil? ? '' : remote_namespace + '/'}#{remote_module_name}' and all items contained in it" + '?')
      end

      post_body = {
        :rsa_pub_key             => SSHUtil.rsa_pub_key_content(),
        :remote_module_name      => remote_module_name,
        :remote_module_namespace => remote_namespace,
        :force_delete            => options.force?
      }

      post rest_url("#{module_type}/delete_remote"), post_body
    end

    def publish_module_aux(context_params)
      module_type  = get_module_type(context_params)
      module_id, input_remote_name = context_params.retrieve_arguments([REQ_MODULE_ID, :option_1], method_argument_names)

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :remote_component_name => input_remote_name,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }
      post_body.merge!(:version => options.version) if options.version?

      # check if module exist on repo manager and use it to decide if need to push or publish
      check_response = post rest_url("#{module_type}/check_remote_exist"), post_body
      return check_response unless check_response.ok?

      # if remote module exist and user call 'publish' command without params then do push;
      # if remote does not exist or user send namespace/name try publish
      response_data = check_response['data']
      if response_data["remote_exist"] && input_remote_name.nil?
        raise DtkValidationError, "You are not allowed to update specific version of #{module_type} module!" if response_data['frozen']
        push_dtkn_module_aux(context_params, true)
      else
        response = post rest_url("#{module_type}/export"), post_body
        return response unless response.ok?

        full_module_name = "#{response.data['remote_repo_namespace']}/#{response.data['remote_repo_name']}"

        DTK::Client::RemoteDependencyUtil.print_dependency_warnings(response, "Module has been successfully published to '#{full_module_name}'!")
        Response::Ok.new()
      end
    end

    def pull_dtkn_aux(context_params)
      module_id, module_name = context_params.retrieve_arguments([REQ_MODULE_ID,REQ_MODULE_NAME,:option_1],method_argument_names)

      catalog      = 'dtkn'
      version      = options.version
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
      version     = options["version"]
      module_type = get_module_type(context_params)

      raise DtkValidationError, "You have to provide valid catalog to push changes to! Valid catalogs: #{PushCatalogs}" unless catalog

      module_location = OsUtil.module_location(resolve_module_type(), module_name, version)
      reparse_aux(module_location) unless internal_trigger
      local_namespace, local_module_name = get_namespace_and_name(module_name,':')

      if catalog.to_s.eql?("dtkn")
        module_refs_content = RemoteDependencyUtil.module_ref_content(module_location)
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
      module_id = context_params.retrieve_arguments([REQ_MODULE_ID], method_argument_names)

      post_body = {
        "#{module_type}_id".to_sym => module_id,
      }

      response = post rest_url("#{module_type}/list_versions"), post_body
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

    def create_new_version_aux(context_params)
      module_type = get_module_type(context_params)
      module_id, version = context_params.retrieve_arguments([REQ_MODULE_ID, :option_1!], method_argument_names)

      module_name = context_params.retrieve_arguments(["#{module_type}_name".to_sym],method_argument_names)
      namespace, name = get_namespace_and_name(module_name,':')

      module_location = OsUtil.module_location(module_type, module_name, nil)
      unless File.directory?(module_location)
        if Console.confirmation_prompt("Module '#{module_name}' has not been cloned. Would you like to clone module now"+'?')
          response = clone_aux(module_type.to_sym, module_id, nil, true)
          return response unless response.ok?
        end
      end

      m_name, m_namespace, repo_url, branch, not_ok_response = workspace_branch_info(module_type, module_id, nil)
      resp = Helper(:git_repo).create_new_version(module_type, branch, name, namespace, version, repo_url)

      post_body = get_workspace_branch_info_post_body(module_type, module_id, version)
      post(rest_url("#{module_type}/create_new_version"), post_body)

      Response::Ok.new()
    end

    def print_ambiguous(ambiguous)
    end

  end
end
