module DTK::Client
  module PurgeCloneMixin
    def purge_clone_aux(module_type,opts={})
      module_name = opts[:module_name]
      version = opts[:version]
      opts_module_loc = (opts[:assembly_module] ? {:assembly_module => opts[:assembly_module]} : Hash.new)
      module_location = OsUtil.module_location(module_type,module_name,version,opts_module_loc)
      pwd = Dir.getwd()
      if ((pwd == module_location) || (pwd.include?("#{module_location}/")))
        OsUtil.print("Local directory '#{module_location}' is not deleted because it is your current working directory.", :yellow) 
        return response
      end

      #TODO: check role '("#{modules_path}/" != module_location))' is playing
      FileUtils.rm_rf(module_location) if (File.directory?(module_location) && ("#{base_path}/" != module_location))
      
      if opts[:delete_all_versions]
        OsUtil.module_version_locations(module_type,module_name,version,opts).each |path|
          FileUtils.rm_rf(path) if File.directory?(path)
      end
    end
  end
end
