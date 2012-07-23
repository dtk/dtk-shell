dtk_require_dtk_common('grit_adapter') #only one adapter now
module DTK; module Client
  class GitRepo
    def self.create_clone_with_branch(type,module_name,repo_url,branch)
      modules_dir = 
        case type
        when :component_module
          Config[:component_modules_dir]
        when :service_module
          Config[:service_modules_dir]
        else
          raise Error.new("Unexpected module type (#{type})")
        end
      unless File.directory?(modules_dir)
        Dir.mkdir(modules_dir)
      end
      target_repo_dir = "#{modules_dir}/#{module_name}"
      adapter_class().clone(target_repo_dir,repo_url,:branch => branch)
    end
    private
    def self.adapter_class()
      Common::GritAdapter
    end
  end
end; end


