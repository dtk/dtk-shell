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
# Do this for each module treated
#      module_id = response.data(:module_id)
#      full_module_name = response.data(:full_module_name)
#      version   = response.data(:version)
#      external_dependencies = response.data(:external_dependencies)
#      dsl_created_info = response.data(:dsl_created_info)

      # Clone It!
 #     clone_response = clone_aux(:component_module, module_id, version, true)
#      return clone_response unless clone_response.ok?

      response
    end
  end
end
=begin
TODO: deprecate
    MODULE_NAME_SEPARATOR = '-'

    def puppet_forge_install_aux(context_params, pf_module_name, module_name, namespace, version, module_type, recursive_call=false)

      response = post rest_url("component_module/install_puppet_module"), {
        :puppetf_module_name => pf_module_name,
        :module_name => module_name,
        :module_version => version,
        :module_namespace => namespace
      }

      return response unless response.ok?
      return response if recursive_call

      check_for_dependencies(pf_module_name, module_type, response.data(:missing_modules), response.data(:found_modules))

      module_id = response.data(:module_id)
      full_module_name = response.data(:full_module_name)
      version   = response.data(:version)
      external_dependencies = response.data(:external_dependencies)
      dsl_created_info = response.data(:dsl_created_info)

      # Clone It!
      clone_response = clone_aux(:component_module, module_id, version, true)
      return clone_response unless clone_response.ok?

      # Create dtk.module.yaml
      if dsl_created_info and !dsl_created_info.empty?
        # cloned module location
        module_dir = clone_response.data(:module_directory)
        repo_obj   = CommandHelper::GitRepo.create(module_dir)

        msg = "A #{dsl_created_info["path"]} file has been created for you, located at #{module_dir}"
        DTK::Client::OsUtil.print(msg,:yellow)
        response = Helper(:git_repo).add_file(repo_obj, dsl_created_info["path"], dsl_created_info["content"], msg)
        return response unless response.ok?
      end

      # TODO: what is purpose of pushing again
      # we push clone changes anyway, user can change and push again
      # context_params.add_context_to_params(module_name, :"component-module", module_id)
      context_params.add_context_to_params(full_module_name, ModuleUtil::type_to_sym(module_type), module_id)
      response = push_module_aux(context_params, true)
    end

  private

    def check_for_dependencies(module_name, module_type, missing_modules=nil, found_modules=nil)
      missing_modules ||= []
      found_modules   ||= []

      puts "Auto-importing missing module(s) from puppet forge" unless missing_modules.empty?

      # print found module (already installed)
      found_modules.each do |fm|
        module_type = fm['type']
        full_module_name =  ModuleUtil.resolve_name(fm['name'], fm['namespace'])
        puts "Using #{module_type.gsub('_',' ')} '#{full_module_name}'"
      end

      missing_modules.each do |dependency|
        full_pf_name = concat_puppet_forge_name(dependency['namespace'], dependency['name'])
        print "Importing component module '#{full_pf_name}' ... "
        response = puppet_forge_install_aux(
                      nil,
                      full_pf_name,
                      dependency['name'],
                      dependency['namespace'],
                      dependency['version'],
                      dependency['type'],
                      true)

        puts (response.ok? ? 'Done.' : 'Error!')
      end
    end

    def concat_puppet_forge_name(namespace, name)
      "#{namespace}#{MODULE_NAME_SEPARATOR}#{name}"
    end

  end
end
=end
