module DTK::Client
  module PuppetForgeMixin

    def puppet_forge_install_aux(context_params, pf_module_name, module_name, namespace, version, module_type)

      response = post rest_url("component_module/install_puppet_forge_modules"), {
        :puppetf_module_name => pf_module_name,
        :module_name => module_name,
        :module_version => version,
        :module_namespace => namespace
      }

      return response unless response.ok?

      print_modules(response.data(:found_modules), 'using')
      print_modules(response.data(:installed_modules), 'installed')

      main_module = response.data(:main_module)
      OsUtil.print("Successfully installed puppet forge module '#{full_module_name(main_module)}'", :yellow)

      nil
  end

    private

    def print_modules(modules, action_name)
      modules.each do |target_module|
        module_name = full_module_name(target_module)
        module_type = target_module['type']

        print "#{action_name.capitalize} dependency #{module_type.gsub('_',' ')} '#{module_name}'\n"
      end
    end

  end
end


