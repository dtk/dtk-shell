dtk_require_dtk_common('grit_adapter')
module DTK
  module Client
    module GitRepo
      def create_clone_with_branch(component_module_name,repo_url,branch)
        component_modules_dir = Config[:component_modules_dir]
        unless File.directory?(component_modules_dir)
          Dir.mkdir(component_modules_dir)
        end
        target_repo_dir = "#{component_modules_dir}/#{component_module_name}"
        Common::GritAdapter.clone(target_repo_dir,repo_url)
      end
    end
  end
end

