dtk_require_dtk_common('grit_adapter') #only one adapter now
module DTK; module Client
  class GitRepo
    def self.create_clone_with_branch(type,module_name,repo_url,branch)
      modules_dir = modules_dir(type)
      Dir.mkdir(modules_dir) unless File.directory?(modules_dir)
      target_repo_dir = local_repo_dir(type,module_name,modules_dir)
      adapter_class().clone(target_repo_dir,repo_url,:branch => branch)
    end

    #returns status indicating what changed
    def self.process_push_changes(type,module_name,branch)
      repo = create(type,module_name,branch)
      status = repo.status()
      return status unless status.any_changes?()

      if status[:untracked]
        status[:untracked].each do |untracked_file|
          #TODO: add untracked
        end
        status.shift_untracked_to_added!()
      end

      #TODO: commit
      #TODO: fetch, do a diff to look for conflicts and push changes
      status
    end
   private
    def self.create(type,module_name,branch)
      adapter_class().new(local_repo_dir(type,module_name),branch)
    end

    def self.modules_dir(type)
      case type
      when :component_module
        Config[:component_modules_dir]
      when :service_module
        Config[:service_modules_dir]
      else
        raise Error.new("Unexpected module type (#{type})")
      end
    end

    def self.local_repo_dir(type,module_name,modules_dir=nil)
      modules_dir ||= modules_dir(type)
      "#{modules_dir}/#{module_name}"
    end

    def self.adapter_class()
      Common::GritAdapter::FileAccess
    end
  end
end; end


