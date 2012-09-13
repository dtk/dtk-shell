dtk_require_dtk_common('grit_adapter') #only one adapter now
dtk_require_dtk_common('errors') 
dtk_require_dtk_common('log') 
module DTK; module Client
  class GitRepo; class << self
    def create_clone_with_branch(type,module_name,repo_url,branch,version=nil)
      modules_dir = modules_dir(type)
      Dir.mkdir(modules_dir) unless File.directory?(modules_dir)
      target_repo_dir = local_repo_dir(type,module_name,version,modules_dir)
      adapter_class().clone(target_repo_dir,repo_url,:branch => branch)
    end

    #returns diffs_summary indicating what is different between lcoal and fetched remote branch
    def process_push_changes(type,module_name,branch)
      repo = create(type,module_name,branch)
      
      #add any file that is untracked
      status = repo.status()
      if status[:untracked]
        status[:untracked].each{|untracked_file_path|repo.add_file_command(untracked_file_path)}
      end

      if status.any_changes?() 
        repo.commit("Pushing changes from client") #TODO: make more descriptive
      end

      repo.fetch_branch(remote())

      #see if any diffs between fetched remote and local branch
      #this has be done after commit
      diffs = repo.diff(remote_branch(branch),branch).ret_summary()
      return diffs unless diffs.any_diffs?()

      #TODO: look for conflicts and push changes
      diffs
    end
   private
    def remote()
      "origin"
    end
    def remote_branch(branch)
      "remotes/#{remote()}/#{branch}"
    end

    def create(type,module_name,branch,version=nil)
      adapter_class().new(local_repo_dir(type,module_name,version),branch)
    end

    def modules_dir(type)
      case type
      when :component_module
        Config[:component_modules_dir]
      when :service_module
        Config[:service_modules_dir]
      else
        raise Error.new("Unexpected module type (#{type})")
      end
    end

    def local_repo_dir(type,module_name,version=nil,modules_dir=nil)
      modules_dir ||= modules_dir(type)
      "#{modules_dir}/#{module_name}#{version && "-#{version}"}"
    end

    def adapter_class()
      Common::GritAdapter::FileAccess
    end
  end; end
end; end


