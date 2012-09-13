dtk_require_dtk_common('grit_adapter') #only one adapter now
dtk_require_dtk_common('errors') 
dtk_require_dtk_common('log') 
module DTK; module Client
  class GitRepo; class << self
    def create_clone_with_branch(type,module_name,repo_url,branch,version=nil)
      Response.wrap_helper_actions do 
        modules_dir = modules_dir(type)
        Dir.mkdir(modules_dir) unless File.directory?(modules_dir)
        target_repo_dir = local_repo_dir(type,module_name,version,modules_dir)
        adapter_class().clone(target_repo_dir,repo_url,:branch => branch)
        {"module_directory" => target_repo_dir}
      end
    end

    def push_changes(type,opts={})
      Response.wrap_helper_actions(:internal) do
        local_repo_dirs(type).map do |repo_dir|
          repo_name = repo_dir.split("/").last
          branch = nil #menaing to use the default branch
          diffs = push_repo_changes(type,repo_dir,branch,opts)
          {repo_name => diffs.inspect}
        end
      end
    end

   private
    #returns diffs_summary indicating what is different between lcoal and fetched remote branch
    def push_repo_changes(type,repo_dir,branch=nil,opts={})
      repo = create(repo_dir,branch)
      branch ||= repo.branch #branch gets filled in if left as nil

      #add any file that is untracked
      status = repo.status()
      if status[:untracked]
        status[:untracked].each{|untracked_file_path|repo.add_file_command(untracked_file_path)}
      end
      
      if status.any_changes?() 
        repo.commit("Pushing changes from client") #TODO: make more descriptive
      end
      
      unless opts[:no_fetch]
        repo.fetch_branch(remote())
      end

      #see if any diffs between fetched remote and local branch
      #this has be done after commit
      diffs = repo.diff(remote_branch(branch),branch).ret_summary()
      return diffs unless diffs.any_diffs?()

      #TODO: look for conflicts and push changes
      diffs
    end

    def remote()
      "origin"
    end
    def remote_branch(branch)
      "remotes/#{remote()}/#{branch}"
    end

    def create(repo_dir,branch=nil)
      adapter_class().new(repo_dir,branch)
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

    def local_repo_dirs(type)
      Dir["#{modules_dir(type)}/*/"].map{|d|d.gsub(Regexp.new("/$"),"")}
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


