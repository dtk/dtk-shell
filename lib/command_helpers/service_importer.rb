dtk_require_from_base('configurator')
module DTK::Client
  #
  # Main purpose of this module is to recognize which local modules are missing based on 
  # name, namespace, version and for those missing component module module will call
  # module#clone and module#import_dtkn method to get missing component modules 
  #
  module ServiceImporter
    def create_missing_clone_dirs()
      ::DTK::Client::Configurator.create_missing_clone_dirs
    end

    def self.error_message(name, errors)
      #TODO: it is contingent whether solution is to fix errors using 'edit' command
      "Module '#{name}' has errors:\n  #{errors.to_s}\nYou can fix errors in the DSL by invoking the 'edit' command.\n"
    end

    ##
    # Method will trigger import for each missing module component
    #
    def trigger_module_component_import(missing_component_list,opts={})      
      puts "Auto-importing missing component module(s)"

      missing_component_list.each do |m_module|
        print "Importing component module '#{m_module['name']}' ... "
        module_name = "#{m_module['namespace']}/#{m_module['name']}"
        module_name += "/#{m_module['version']}" if m_module['version']
        new_context_params = ::DTK::Shell::ContextParams.new([module_name])
        new_context_params.override_method_argument!('option_2', m_module['version'])
        new_context_params.forward_options( { "skip_cloning" => true}).merge!(opts)

        response = ContextRouter.routeTask("component_module", "install", new_context_params, @conn)
        puts(response.data(:does_not_exist) ? response.data(:does_not_exist) : "Done.")
        raise DTK::Client::DtkError, response.error_message unless response.ok?        
      end
      
      Response::Ok.new()
    end

    def resolve_missing_components(service_module_id, service_module_name, namespace_to_use, force_clone=false)
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
        is_install_dependencies = true
        is_install_dependencies = Console.confirmation_prompt("\nDo you want to clone missing component module dependencies") unless force_clone

        # we get list of modules available on server

        new_context_params = nil

        if is_install_dependencies
          needed_modules.each do |m|
            formated_name = m['formated_name']
            print "Cloning component module '#{formated_name}' from server ... "
            thor_options = {}
            thor_options["version"] = m['version']
            thor_options["skip_edit"] = true
            thor_options["omit_output"] = true
            new_context_params = ::DTK::Shell::ContextParams.new
            new_context_params.forward_options(thor_options)
            new_context_params.add_context_to_params(formated_name, :"component-module", m['id'])             
            response = ContextRouter.routeTask("component_module", "clone", new_context_params, @conn)
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
