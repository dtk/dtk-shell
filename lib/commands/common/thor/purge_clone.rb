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
            response = Response::Error.new()
          else
            FileUtils.rm_rf(dir)
          end
        end
      end
      response
    end
  end
end
