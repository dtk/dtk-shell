module DTK::Client
  module PuppetForgeMixin

    def puppet_forge_install_aux(context_params, pf_module_name, module_name, namespace, version, module_type)
      post_body_hash = {
        :puppetf_module_name => pf_module_name,
        :module_name?        => module_name,
        :module_version?     => version,
        :module_namespace?   => namespace
      }

      response = post rest_url("component_module/install_puppet_forge_modules"),PostBody.new(post_body_hash)

      return response unless response.ok?


      installed_modules = response.data(:installed_modules)

      print_modules(response.data(:found_modules), 'using')
      print_modules(installed_modules, 'installed')

      main_module = response.data(:main_module)

      unless installed_modules.empty?
        clone_deps = Console.confirmation_prompt("\nDo you want to clone newly installed dependencies?")
        if clone_deps
          installed_modules.each do |im|
            clone_aux(im['type'], im['id'], im['version'], true)
          end
        end
      end

      clone_aux(main_module['type'], main_module['id'], main_module['version'])
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


