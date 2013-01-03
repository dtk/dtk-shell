dtk_require_dtk_common('grit_adapter') #only one adapter now
dtk_require_dtk_common('errors') 
dtk_require_dtk_common('log') 
require 'fileutils'

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

    def push_all_changes(type,opts={})
      Response.wrap_helper_actions() do
        local_repo_dirs(type).map do |repo_dir|
          repo_name = repo_dir.split("/").last
          repo = create(repo_dir)
          diffs = push_repo_changes_aux(repo,opts)
          {repo_name => diffs.inspect}
        end
      end
    end

    #TODO: this does not push; may make that an option
    def add_file(repo_branch,path,content,msg=nil)
      Response.wrap_helper_actions() do
        ret = Hash.new
        repo_branch.add_file(path,content)
        repo_branch.add_file_command(path)
        ret["message"] = msg if msg
        ret
      end
    end

    #TODO: not treating versions yet
    #opts can have the following keys
    #
    #:remote_repo
    #:remote_branch
    #:remote_repo_url
    #:local_branch
    #:no_fetch
    #
    def push_changes(type,module_name,opts={})
      Response.wrap_helper_actions() do
        repo_dir = local_repo_dir(type,module_name)
        repo = create(repo_dir,opts[:local_branch])
        diffs = push_repo_changes_aux(repo,opts)
        {"diffs" => diffs}
      end
    end

    #if local clone exists remove its .git directory
    def unlink_local_clone?(type,module_name,version=nil)
      local_repo_dir = local_repo_dir(type,module_name,version)
      git_dir = "#{local_repo_dir}/.git"
      if File.directory?(git_dir)
        FileUtils.rm_rf(git_dir)
      end
    end

    def check_local_dir_exists(type,module_name,version=nil)
      Response.wrap_helper_actions() do
        ret = Hash.new
        local_repo_dir = local_repo_dir(type,module_name,version)
        unless File.directory?(local_repo_dir)
          raise ErrorUsage.new("The content for module (#{module_name}) should be put in directory (#{local_repo_dir})")
        end
        {"module_directory" => local_repo_dir}
      end
    end

    def initialize_repo_and_push(type,module_name,branch_info,repo_url)
       Response.wrap_helper_actions() do
        ret = Hash.new
        lib_branch = branch_info[:library]
        ws_branch = branch_info[:workspace]

        ret = Hash.new
        repo_dir = local_repo_dir(type,module_name)

        #first create library branch then workspace branch then remove local branch to library
        repo_lib_branch = create_or_init(type,repo_dir,lib_branch)      
        repo_lib_branch.add_or_update_remote(remote(),repo_url)
        repo_lib_branch.fetch(remote())
        repo_lib_branch.add_file_command(".")
        repo_lib_branch.commit("Adding files during initialization")
        repo_lib_branch.push()

        #create and commit workspace branch
        repo_lib_branch.add_branch?(ws_branch)
        repo_ws_branch = create(repo_dir,ws_branch)
        #push changes
        repo_ws_branch.push()

        #remove lib branch
        repo_ws_branch.remove_branch?(lib_branch)
        {"repo_branch" => repo_ws_branch}
      end
    end

   private
    def push_repo_changes_aux(repo,opts={})
      diffs = Hash.new
      #add any file that is untracked
      status = repo.status()
      if status[:untracked]
        status[:untracked].each{|untracked_file_path|repo.add_file_command(untracked_file_path)}
      end
      
      if status.any_changes?() 
        repo.commit("Pushing changes from client") #TODO: make more descriptive
      end

      if opts[:remote_repo] and opts[:remote_repo_url]
        repo.add_remote?(opts[:remote_repo],opts[:remote_repo_url])
      end
      
      unless opts[:no_fetch]
        repo.fetch(remote(opts[:remote_repo]))
      end

      local_branch = repo.branch 
      remote_branch_ref = remote_branch_ref(local_branch,opts)

      #check if merge needed
      merge_rel = repo.ret_merge_relationship(:remote_branch,remote_branch_ref)
      if merge_rel == :equal
        diffs
      elsif [:branchpoint,:local_behind].include?(merge_rel)
        raise ErrorUsage.new("Merge needed before module (#{pp_module(repo)}) can be pushed to server")
      elsif merge_rel == :local_ahead
        #see if any diffs between fetched remote and local branch
        #this has be done after commit
        diffs = repo.diff("remotes/#{remote_branch_ref}",local_branch).ret_summary()
        return diffs unless diffs.any_diffs?()

        repo.push(remote_branch_ref)

        diffs
      else
        raise Error.new("Unexpected merge_rel (#{merge_rel})")
      end
    end

    def remote(remote_repo=nil)
      remote_repo||"origin"
    end
    def remote_branch_ref(local_branch,opts={})
      "#{remote(opts[:remote_repo])}/#{opts[:remote_branch]||local_branch}"
    end

    def create_or_init(type,repo_dir,branch)
      create_opts = (local_repo_dirs(type).include?(repo_dir) ? {} : {:init => true})
      create(repo_dir,branch,create_opts)
    end

    def create(repo_dir,branch=nil,opts={})
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


