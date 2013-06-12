module DTK::Client
  #
  # Main purpose of this module is to recognize which local modules are missing based on 
  # name, namespace, version and for those missing component module module will call
  # module#clone and module#import_r8n method to get missing component modules 
  #
  module ServiceImporter


    ##
    # Method will trigger import for each missing module component
    #
    def trigger_module_component_import(missing_component_list)
      puts "Auto-importing missing module(s)"
      missing_component_list.each do |m_module|
        print "Importing module component '#{m_module['name']}' ... "
        new_context_params = ::DTK::Shell::ContextParams.new(["#{m_module['namespace']}/#{m_module['name']}"])
        response = ContextRouter.routeTask("module", "import_r8n", new_context_params, @conn)
        raise DTK::Client::DtkError, response.error_message unless response.ok?
        puts "Done."
      end
    end

    def resolve_missing_components(service_module_id, service_module_name, namespace_to_use)
      # Get dependency component modules and cross reference them with local component modules
      module_component_list = post rest_url("service_module/list_component_modules"), { :service_module_id => service_module_id }
      local_modules, needed_modules = OsUtil.local_component_module_list(), Array.new

      module_component_list.data.each do |dependency_module|
        unless local_modules.include?(formated_name = formulate_module_name(dependency_module['display_name'], dependency_module['version']))
          needed_modules << dependency_module.merge({'formated_name' => formated_name})
        end
      end

      unless needed_modules.empty?
        puts "Service '#{service_module_name}' has following dependencies: \n\n"
        needed_modules.each { |m| puts " - #{m['formated_name']}" }
        is_install_dependencies = Console.confirmation_prompt("\nDo you want to clone missing module component dependencies")

        # we get list of modules available on server

        new_context_params = nil

        if is_install_dependencies
          needed_modules.each do |m|
            print "Cloning component module '#{m['formated_name']}' from server ... "
            thor_options = {}
            thor_options["version"] = m['version']
            thor_options["skip_edit"] = true
            thor_options["omit_output"] = true
            new_context_params = ::DTK::Shell::ContextParams.new
            new_context_params.forward_options(thor_options)
            new_context_params.add_context_to_params("module", "module", m['id'])               
            response = ContextRouter.routeTask("module", "clone", new_context_params, @conn)
            puts "Done."
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

      versions.collect { |version| formulate_module_name(e['display_name'], version)}
    end

    # Resolves local module name
    #
    # Returns: String
    def formulate_module_name(display_name, version)
      version = nil if 'CURRENT'.eql?(version)
      (version ? "#{display_name}-#{version.strip}" : "#{display_name}")
    end

  end
end