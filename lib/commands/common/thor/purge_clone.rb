module DTK::Client
  module PurgeCloneMixin
    def purge_clone_aux(module_type,opts={})
      module_name = opts[:module_name]
      version = opts[:version]
      opts_module_loc = (opts[:assembly_module] ? {:assembly_module => opts[:assembly_module]} : Hash.new)
      module_location = OsUtil.module_location(module_type,module_name,version,opts_module_loc)
      dirs_to_delete = [module_location]
      if opts[:delete_all_versions]
        dirs_to_delete += OsUtil.module_version_locations(module_type,module_name,version,opts)
      end
      response = Response::Ok.new()
      pwd = Dir.getwd()
      dirs_to_delete.each do |dir|
        if File.directory?(dir)
          if ((pwd == dir) || (pwd.include?("#{dir}/")))
            OsUtil.print("Local directory '#{dir}' is not deleted because it is your current working directory.", :yellow)
          else
            FileUtils.rm_rf(dir)
          end
        end
      end
      response
    end

    def check_if_unsaved_changes(assembly_or_workspace_id, opts={})
      unsaved_modules = []
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :subtype     => 'instance'
      }
      response = post rest_url("assembly/get_component_modules"), post_body

      if response.ok?
        response.data.each do |cmp_mod|
          unsaved_modules << "#{cmp_mod['namespace_name']}:#{cmp_mod['display_name']}" if cmp_mod['local_copy_diff']
        end
      end

      unsaved_modules
    end

  end
end
