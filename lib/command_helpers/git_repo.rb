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
      Response.wrap_helper_actions() do
        local_repo_dirs(type).map do |repo_dir|
          repo_name = repo_dir.split("/").last
          branch = nil #meaning to use the default branch
          diffs = push_repo_changes(repo_dir,branch,opts)
          {repo_name => diffs.inspect}
        end
      end
    end

    def check_local_dir_exists(type,module_name,version=nil)
      Response.wrap_helper_actions() do
        ret = Hash.new
        local_repo_dir = local_repo_dir(type,module_name,version)
        unless File.directory?(local_repo_dir)
          raise ErrorUsage.new("The content for module (#{module_name}) should be put in directory (#{local_repo_dir})")
        end
        ret
      end
    end

    def initialize_repo_and_push(type,module_name,branch,repo_url)
       Response.wrap_helper_actions() do
        ret = Hash.new
        repo_dir = local_repo_dir(type,module_name)
        create_or_init(type,repo_dir,branch)      
        ret
      end
    end

   private
    #returns diffs_summary indicating what is different between lcoal and fetched remote branch
    def push_repo_changes(repo_dir,branch=nil,opts={})
      diffs = Hash.new
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
        repo.fetch(remote())
      end

      remote_branch = remote_branch(branch)

      #check if merge needed
      merge_rel = repo.ret_merge_relationship(:remote_branch,remote_branch)
      pp [:debug,pp_module(repo),:merge_rel,merge_rel]
      if merge_rel == :equal
        diffs
      elsif [:branchpoint,:local_behind].include?(merge_rel)
        raise ErrorUsage.new("Merge needed before module (#{pp_module(repo)}) can be pushed to server")
      elsif merge_rel == :local_ahead
        #see if any diffs between fetched remote and local branch
        #this has be done after commit
        diffs = repo.diff("remotes/#{remote_branch}",branch).ret_summary()
        return diffs unless diffs.any_diffs?()

        repo.push()

        diffs
      else
        raise Error.new("Unexpected merge_rel (#{merge_rel})")
      end
    end

    def remote()
      "origin"
    end
    def remote_branch(branch)
      "#{remote()}/#{branch}"
    end

    def create_or_init(type,repo_dir,branch)
      create_opts = (local_repo_dirs(type).include?(repo_dir) ? {} : {:init => true})
      create(repo_dir,branch,create_opts)
    end

    def create(repo_dir,branch,opts={})
      adapter_class().new(repo_dir,branch,opts)
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
      Dir["/root/component_modules/*/.git"].map{|d|d.gsub(Regexp.new("/\.git$"),"")}
    end

    def local_repo_dir(type,module_name,version=nil,modules_dir=nil)
      modules_dir ||= modules_dir(type)
      "#{modules_dir}/#{module_name}#{version && "-#{version}"}"
    end

    def adapter_class()
      Common::GritAdapter::FileAccess
    end

    def pp_module(repo)
      repo.repo_dir.gsub(Regexp.new("/$"),"").split("/").last
    end
  end; end
end; end


