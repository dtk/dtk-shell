dtk_require_dtk_common('grit_adapter') #only one adapter now
module DTK; module Client
  class GitRepo
    def self.create_clone_with_branch(component_module_name,repo_url,branch)
      component_modules_dir = Config[:component_modules_dir]
      unless File.directory?(component_modules_dir)
        Dir.mkdir(component_modules_dir)
      end
      target_repo_dir = "#{component_modules_dir}/#{component_module_name}"
      adapter_class().clone(target_repo_dir,repo_url,:branch => branch)
    end
    private
    def self.adapter_class()
      Common::GritAdapter
    end
  end
end; end


