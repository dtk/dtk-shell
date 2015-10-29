dtk_require_from_base('configurator')
module DTK::Client
  #
  # Main purpose of this module is to recognize which local modules are missing based on
  # name, namespace, version and for those missing component module module will call
  # module#clone and module#import_dtkn method to get missing component modules
  #
  module ServiceImporter
    def create_missing_clone_dirs()
      Configurator.create_missing_clone_dirs
    end

    def self.error_message(name, errors, opts = {})
      prefix = ''
      unless opts[:module_type] == :service_module
        prefix = "Module '#{name}' has errors:\n  "
      end
      command = opts[:command] || 'edit'
      "#{prefix}#{errors.to_s}\nYou can fix errors by invoking the '#{command}' command.\n"
    end

    ##
    # Method will trigger pull from dtkn for each existing module
    #
    def trigger_module_auto_pull(required_modules, opts = {})
      return if required_modules.empty?

      # options[:force] means this command is triggered from trigger_module_auto_import method bellow
      unless opts[:force]
        update_none = RemoteDependencyUtil.check_for_frozen_modules(required_modules)

        if update_none
          print "All dependent modules are frozen and will not be updated!\n"
          print "Resuming pull ... "
          return Response::Ok.new()
        end
      end

      if opts[:force] || Console.confirmation_prompt("Do you want to update in addition to this module its dependent modules from the catalog?")
        required_modules.each do |r_module|
          module_name = full_module_name(r_module)
          module_type = r_module['type']
          version     = r_module['version']
          full_name   = (version && !version.eql?('master')) ? "#{module_name}(#{version})" : module_name

          if r_module['frozen']
            print "Not allowed to update frozen #{module_type.gsub('_', ' ')} '#{module_name}' version '#{version}' \n"
            next
          end

          print "Pulling #{module_type.gsub('_',' ')} content for '#{full_name}' ... "

          new_context_params = DTK::Shell::ContextParams.new
          new_context_params.add_context_to_params(module_type, module_type)
          new_context_params.add_context_name_to_params(module_type, module_type, module_name)

          forwarded_opts = { :skip_recursive_pull => true, :ignore_dependency_merge_conflict => true }
          forwarded_opts.merge!(:do_not_raise => true) if opts[:do_not_raise]
          forwarded_opts.merge!(:version => version) if version && !version.eql?('master')
          new_context_params.forward_options(forwarded_opts)

          response = ContextRouter.routeTask(module_type, "update", new_context_params, @conn)

          unless response.ok?
            if opts[:do_not_raise]
              OsUtil.print("#{response.error_message}", :red)
            else
              raise DtkError, response.error_message
            end
          end
        end

        print "Resuming pull ... " unless opts[:force]
      end
    end

    ##
    # Method will trigger import for each missing module component
    #
    def trigger_module_auto_import(modules_to_import, required_modules, opts = {})
      puts 'Auto-installing missing module(s)'
      update_all  = false
      update_none = RemoteDependencyUtil.check_for_frozen_modules(required_modules)

      # Print out or update installed modules from catalog
      required_modules.each do |r_module|
        module_name         = full_module_name(r_module)
        module_type         = r_module['type']
        version             = r_module['version']
        full_name           = (version && !version.eql?('master')) ? "#{module_name}(#{version})" : module_name

        print "Using #{module_type.gsub('_', ' ')} '#{full_name}'\n"
        next if update_none || opts[:update_none]

        if update_all
          trigger_module_auto_pull([r_module], :force => true, :do_not_raise => true)
        else
          options = required_modules.size > 1 ? %w(all none) : []
          update  = Console.confirmation_prompt_additional_options("Do you want to update dependent #{module_type.gsub('_', ' ')} '#{full_name}' from the catalog?", options)
          next unless update

          if update.to_s.eql?('all')
            update_all = true
            trigger_module_auto_pull([r_module], :force => true, :do_not_raise => true)
          elsif update.to_s.eql?('none')
            update_none = true
          else
            trigger_module_auto_pull([r_module], :force => true, :do_not_raise => true)
          end
        end
      end

      # Trigger import/install for missing modules
      modules_to_import.each do |m_module|
        module_name = full_module_name(m_module)
        module_type = m_module['type']
        version     = m_module['version']
        full_name   = (version && !version.eql?('master')) ? "#{module_name}(#{version})" : module_name

        # we check if there is module_url if so we install from git
        module_url  = m_module['module_url']

        # descriptive message
        importing  = module_url ? "Importing" : "Installing"
        import_msg = "#{importing} #{module_type.gsub('_', ' ')} '#{full_name}'"
        import_msg += " from git source #{module_url}" if module_url
        print "#{import_msg} ... "

        if module_url
          # import from Git source
          new_context_params = ::DTK::Shell::ContextParams.new([module_url, module_name])
          new_context_params.forward_options(:internal_trigger => true)
          response = ContextRouter.routeTask(module_type, 'import_git', new_context_params, @conn)
        else
          # import from Repo Manager
          new_context_params = ::DTK::Shell::ContextParams.new([module_name])
          new_context_params.override_method_argument!('option_2', version) if version && !version.eql?('master')
          new_context_params.forward_options(:skip_cloning => false, :skip_auto_install => true, :module_type => module_type).merge!(opts)
          response = ContextRouter.routeTask(module_type, 'install', new_context_params, @conn)
        end

        ignore_component_error = (new_context_params.get_forwarded_options() || {})[:ignore_component_error] && module_type.eql?('component_module')
        puts(response.data(:does_not_exist) ? response.data(:does_not_exist) : 'Done.')
        raise DtkError, response.error_message if !response.ok? && !ignore_component_error
      end

      Response::Ok.new()
    end

    def resolve_missing_components(service_module_id, service_module_name, namespace_to_use, force_clone=false)
      # Get dependency component modules and cross reference them with local component modules
      module_component_list = post rest_url("service_module/list_component_modules"), { :service_module_id => service_module_id }

      local_modules, needed_modules = OsUtil.local_component_module_list(), Array.new

      if module_component_list
        module_component_list.data.each do |cmp_module|
          with_namespace = ModuleUtil.resolve_name(cmp_module["display_name"],cmp_module["namespace_name"])
          formated_name = add_version?(with_namespace, cmp_module['version'])
          unless local_modules.include?(formated_name)
            needed_modules << cmp_module.merge({'formated_name' => formated_name})
          end
        end
      end

      unless needed_modules.empty?
        # puts "Service '#{service_module_name}' does not have the following component modules dependencies on the client machine: \n\n"
        # needed_modules.each { |m| puts " - #{m['formated_name']}" }
        is_install_dependencies = true
        # is_install_dependencies = Console.confirmation_prompt("\nDo you want to clone these missing component modules to the client machine?") unless force_clone

        # we get list of modules available on server

        new_context_params = nil

        if is_install_dependencies
          needed_modules.each do |m|
            formated_name = m['formated_name']
            # print "Cloning component module '#{formated_name}' from server ... "
            thor_options = {}
            thor_options["version"] = m['version'] unless m['version'].eql?('base')
            thor_options["skip_edit"] = true
            thor_options["omit_output"] = true
            thor_options.merge!(:module_type => 'component-module')
            new_context_params = ::DTK::Shell::ContextParams.new
            new_context_params.forward_options(thor_options)
            new_context_params.add_context_to_params(formated_name, :"component-module", m['id'])

            begin
              response = ContextRouter.routeTask("component_module", "clone", new_context_params, @conn)
            rescue DtkValidationError => e
              # ignoring this
            end
            # puts "Done."
          end
        end
      end
    end

    private
    #
    # As the result we can have multiple version so we need to resolve them
    #
    # Returns: Array<String>
    def resolve_module_names(e)
      versions = (e['version'] ? e['version'].split(',') : ['CURRENT'])

      versions.collect { |version| add_version?(e['display_name'], version)}
    end

    # Resolves local module name
    #
    # Returns: String
    def add_version?(display_name, version)
      version = nil if 'CURRENT'.eql?(version) || 'base'.eql?(version)
      (version ? "#{display_name}-#{version.strip}" : "#{display_name}")
    end

  private

    def full_module_name(module_hash)
      ModuleUtil.join_name(module_hash['name'], module_hash['namespace'])
    end

  end
end
