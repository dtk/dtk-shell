dtk_require_dtk_common('grit_adapter') #only one adapter now
dtk_require_dtk_common('errors') 
dtk_require_dtk_common('log') 
require 'fileutils'

module DTK; module Client; class CommandHelper
  class GitRepo < self; class << self
    def create_clone_with_branch(type,module_name,repo_url,branch,version=nil)
      Response.wrap_helper_actions do 
        modules_dir = modules_dir(type)
        Dir.mkdir(modules_dir) unless File.directory?(modules_dir)
        target_repo_dir = local_repo_dir(type,module_name,version,modules_dir)
        adapter_class().clone(target_repo_dir,repo_url,:branch => branch)
        {"module_directory" => target_repo_dir}
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

    def local_clone_dir_exists?(type,module_name,version=nil)
      ret = local_repo_dir(type,module_name,version)
      File.directory?(ret) && ret
    end
    def local_clone_exists?(type,module_name,version=nil)                  
      repo_dir = local_repo_dir(type,module_name,version)
      ret = "#{repo_dir}/.git"
      File.directory?(ret) && ret
    end

    #opts can have the following keys
    #
    #:remote_repo
    #:remote_branch
    #:remote_repo_url
    #:local_branch
    #:no_fetch
    #
    def push_changes(type,module_name,version,opts={})
      Response.wrap_helper_actions() do
        repo_dir = local_repo_dir(type,module_name,version)
        repo = create(repo_dir,opts[:local_branch])
        push_repo_changes_aux(repo,opts)
      end
    end

    #TODO: not treating versions yet
    #opts can have the following keys
    #
    #:remote_repo
    #:remote_branch
    #:remote_repo_url
    #:local_branch
    #
    def pull_changes(type,module_name,opts={})
      Response.wrap_helper_actions() do
        repo_dir = local_repo_dir(type,module_name)
        repo = create(repo_dir,opts[:local_branch])
        diffs = pull_repo_changes_aux(repo,opts)
        {"diffs" => diffs}
      end
    end
    def pull_changes?(type,module_name,opts={})
      if local_clone_exists?(type,module_name)
        pull_changes(type,module_name,opts)
      else
        Response.wrap_helper_actions() 
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
    #TODO: in common expose Common::GritAdapter at less nested level
    class DiffSummary < Common::GritAdapter::FileAccess::Diffs::Summary
      def self.new_version()
        new(:new_version => true)
      end
      
      def self.diff(repo,ref1,ref2)
        new(repo.diff(ref1,ref2).ret_summary())
      end
    end
    
    #returns hash with keys
    #: diffs - hash with diffs
    # commit_sha - sha of currenet_commit
    def push_repo_changes_aux(repo,opts={})
      diffs = DiffSummary.new()
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
      commit_shas = Hash.new
      merge_rel = repo.ret_merge_relationship(:remote_branch,remote_branch_ref, :ret_commit_shas => commit_shas)
      commit_sha = nil
      if merge_rel == :equal
        commit_sha = commit_shas[:other_sha]
      elsif [:branchpoint,:local_behind].include?(merge_rel)
        raise ErrorUsage.new("Merge needed before module (#{pp_module(repo)}) can be pushed to server")
      elsif merge_rel == :no_remote_ref
        repo.push(remote_branch_ref)
        diffs = DiffSummary.new_version()
        commit_sha = commit_shas[:local_sha]
      elsif merge_rel == :local_ahead
        #see if any diffs between fetched remote and local branch
        #this has be done after commit
        diffs = DiffSummary.diff(repo,"remotes/#{remote_branch_ref}",local_branch)
        if diffs.any_diffs?()
          repo.push(remote_branch_ref)
        end
        commit_sha = repo.find_remote_sha(remote_branch_ref)
      else
        raise Error.new("Unexpected merge_rel (#{merge_rel})")
      end
      {"diffs" => diffs, "commit_sha" => commit_sha}
    end

    def pull_repo_changes_aux(repo,opts={})
      diffs = DiffSummary.new()
      if opts[:remote_repo] and opts[:remote_repo_url]
        repo.add_remote?(opts[:remote_repo],opts[:remote_repo_url])
      end
      repo.fetch(remote(opts[:remote_repo]))

      local_branch = repo.branch 
      remote_branch_ref = remote_branch_ref(local_branch,opts)

      #check if merge needed
      merge_rel = repo.ret_merge_relationship(:remote_branch,remote_branch_ref)
      if merge_rel == :equal
        diffs
      elsif [:branchpoint,:local_ahead].include?(merge_rel)
#        raise ErrorUsage.new("Merge needed before module (#{pp_module(repo)}) can be pulled from server")
        raise Error.new("TODO: need to write code when there is a branchpoint or local_ahead")
      elsif merge_rel == :local_behind
        #see if any diffs between fetched remote and local branch
        #this has be done after commit
        diffs = DiffSummary.diff(repo,"remotes/#{remote_branch_ref}",local_branch)
        return diffs unless diffs.any_diffs?()

        repo.merge(remote_branch_ref)

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
end; end; end


