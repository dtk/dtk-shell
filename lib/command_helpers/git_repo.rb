require 'fileutils'
dtk_require("../domain/git_adapter")
dtk_require("../domain/git_error_handler")

module DTK; module Client; class CommandHelper
  class GitRepo < self; class << self

    def create(repo_dir,branch=nil,opts={})
      GitAdapter.new(repo_dir,branch)
    end

    def create_clone_with_branch(type, module_name, repo_url, branch=nil, version=nil, module_namespace=nil, opts={})
      Response.wrap_helper_actions do
        full_name = module_namespace ? ModuleUtil.resolve_name(module_name, module_namespace) : module_name

        modules_dir = modules_dir(type,full_name,version,opts)
        FileUtils.mkdir_p(modules_dir) unless File.directory?(modules_dir)
        target_repo_dir = local_repo_dir(type,full_name,version,opts)

        opts = {}
        opts = { :branch => branch } if branch
        begin
          GitAdapter.clone(repo_url, target_repo_dir, opts[:branch])
        rescue => e
          # Handling Git error messages with more user friendly messages
          e = GitErrorHandler.handle(e)

          #cleanup by deleting directory
          FileUtils.rm_rf(target_repo_dir) if File.directory?(target_repo_dir)
          error_msg = "Clone to directory (#{target_repo_dir}) failed"

          DtkLogger.instance.error_pp(e.message, e.backtrace)

          raise ErrorUsage.new(error_msg,:log_error=>false)
        end
        {"module_directory" => target_repo_dir}
      end
    end

    #TODO: this does not push; may make that an option
    def add_file(repo_obj,path,content,msg=nil)
      Response.wrap_helper_actions() do
        ret = Hash.new
        repo_obj.add_file(path,content)
        ret["message"] = msg if msg
        ret
      end
    end

    def local_clone_dir_exists?(type,module_name,namespace=nil,version=nil)
      full_name = ModuleUtil.resolve_name(module_name, namespace)
      ret = local_repo_dir(type,full_name,version)
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
    def push_changes(type,full_module_name,version,opts={})
      Response.wrap_helper_actions() do
        repo_dir = local_repo_dir(type,full_module_name,version,opts)
        repo = create(repo_dir,opts[:local_branch])
        push_repo_changes_aux(repo,opts)
      end
    end

    def get_diffs(type, module_name, version, opts={})
      Response.wrap_helper_actions() do
        repo_dir = local_repo_dir(type,module_name,version)
        repo = create(repo_dir,opts[:local_branch])
        get_diffs_aux(repo,opts)
      end
    end

    #opts can have the following keys
    #
    #:remote_repo
    #:remote_branch
    #:remote_repo_url
    #:local_branch
    #:version
    #:commit_sha
    #
    # returns:
    # { :diffs => , :commit_sha => }
    def pull_changes(type,module_name,opts={})
      Response.wrap_helper_actions() do
        repo_dir = local_repo_dir(type,module_name,opts[:version],opts)
        repo = create(repo_dir,opts[:local_branch])
        response = pull_repo_changes_aux(repo,opts)
        response
      end
    end
    def pull_changes?(type,module_name,opts={})
      if local_clone_exists?(type,module_name)
        pull_changes(type,module_name,opts)
      else
        Response.wrap_helper_actions()
      end
    end

    def synchronize_clone(type,module_name,commit_sha,opts={})
      pull_changes?(type,module_name,{:commit_sha => commit_sha}.merge(opts))
      Response::Ok.new()
    end

    # if local clone exists remove its .git directory
    def unlink_local_clone?(type,module_name,version=nil)
      Response.wrap_helper_actions() do
        local_repo_dir = local_repo_dir(type,module_name,version)
        git_dir = "#{local_repo_dir}/.git"
        if File.directory?(git_dir)
          FileUtils.rm_rf(git_dir)
        end
      end
    end

    def check_local_dir_exists_with_content(type,module_name,version=nil)
      Response.wrap_helper_actions() do
        ret = Hash.new
        local_repo_dir = local_repo_dir(type,module_name,version)

        unless File.directory?(local_repo_dir)
          raise ErrorUsage.new("The content for module (#{module_name}) should be put in directory (#{local_repo_dir})")
        end

        # transfered this part to initialize_client_clone_and_push because if we remove .git folder and
        # if create on server fails we will lose this .git folder and will not be able to push local changes to server
        # if File.directory?("#{local_repo_dir}/.git")
        #   response =  unlink_local_clone?(type,module_name,version)
        #   unless response.ok?
        #     # in case delete went wrong, we raise usage error
        #     raise ErrorUsage.new("Directory (#{local_repo_dir} is set as a git repo; to continue it must be a non git repo; this can be handled by shell command 'rm -rf #{local_repo_dir}/.git'")
        #   end

        #   # we return to normal flow, since .git dir is removed
        # end

        if Dir["#{local_repo_dir}/*"].empty?
          raise ErrorUsage.new("Directory (#{local_repo_dir}) must have ths initial content for module (#{module_name})")
        end
        {"module_directory" => local_repo_dir}
      end
    end

    def rename_and_initialize_clone_and_push(type, module_name, new_module_name, branch, repo_url, local_repo_dir, version = nil)
      old_dir = local_repo_dir
      new_dir = local_repo_dir.gsub(/#{module_name}$/, new_module_name)

      # Moving directory
      FileUtils.mv(old_dir, new_dir)

      # Continue push
      initialize_client_clone_and_push(type, new_module_name, branch, repo_url, new_dir, version)
    end

    # makes repo_dir (determined from type and module_name) into a git dir, pulls, adds, content and then pushes
    def initialize_client_clone_and_push(type, module_name, branch, repo_url, local_repo_dir, version=nil)
      # moved this part from 'check_local_dir_exists_with_content' to this method since this only deletes .git folder
      # which can cause us problems if import fails
      if File.directory?("#{local_repo_dir}/.git")
        response =  unlink_local_clone?(type,module_name,version)
        unless response.ok?
          # in case delete went wrong, we raise usage error
          raise ErrorUsage.new("Directory (#{local_repo_dir} is set as a git repo; to continue it must be a non git repo; this can be handled by shell command 'rm -rf #{local_repo_dir}/.git'")
        end
        # we return to normal flow, since .git dir is removed
      end

      Response.wrap_helper_actions() do
        ret = Hash.new
        repo_dir = local_repo_dir(type,module_name)

        repo = create(repo_dir,branch,:init => true, :no_initial_commit => true)
        repo.add_remote(remote(),repo_url)
        remote_branch = local_branch = branch

        repo.pull_remote_to_local(remote_branch,local_branch,remote())
        repo.stage_changes()
        repo.commit("Adding files during initialization")
        repo.push_with_remote(remote(), remote_branch)

        commit_sha = repo.head_commit_sha()
        {"repo_obj" => repo,"commit_sha" => commit_sha}
      end
    end

   private
    # TODO: in common expose Common::GritAdapter at less nested level
    class DiffSummary < ::DTK::Common::SimpleHashObject
      def self.new_version(repo)
        new(repo.new_version())
      end

      def self.diff(repo,local_branch,remote_reference)
        new(repo.diff_summary(local_branch,remote_reference))
      end

      def self.diff_remote(repo,ref1)
        new(repo.diff(ref1).ret_summary())
      end

      def any_diffs?
        changes = false
        self.each do |k,v|
          unless v.empty?
            changes = true
            break
          end
        end
        changes
      end
    end

    #returns hash with keys
    #: diffs - hash with diffs
    # commit_sha - sha of currenet_commit
    def push_repo_changes_aux(repo,opts={})
      diffs = DiffSummary.new()

      # adding untracked files (newly added files)
      repo.stage_changes()

      # commit if there has been changes
      if repo.changed?
        repo.commit(opts[:commit_msg]||"Pushing changes from client") #TODO: make more descriptive
      end

      if opts[:remote_repo] and opts[:remote_repo_url]
        repo.add_remote(opts[:remote_repo],opts[:remote_repo_url])
      end

      unless opts[:no_fetch]
        repo.fetch(remote(opts[:remote_repo]))
      end

      local_branch = repo.local_branch_name

      remote_branch_ref = remote_branch_ref(local_branch, opts)

      #check if merge needed
      commit_shas = Hash.new
      merge_rel = repo.merge_relationship(:remote_branch,remote_branch_ref, :ret_commit_shas => commit_shas)
      commit_sha = nil
      if merge_rel == :equal
        commit_sha = commit_shas[:other_sha]
      elsif [:branchpoint,:local_behind].include?(merge_rel)
        raise ErrorUsage.new("Merge needed before module (#{pp_module(repo)}) can be pushed to server")
      elsif merge_rel == :no_remote_ref
        repo.push(remote_branch_ref)
        diffs = DiffSummary.new_version(repo)
        commit_sha = commit_shas[:local_sha]
      elsif merge_rel == :local_ahead
        # see if any diffs between fetched remote and local branch
        # this has be done after commit

        diffs = DiffSummary.diff(repo,local_branch, remote_branch_ref)


        if diffs.any_diffs?()
          repo.push(remote_branch_ref)
        end

        commit_sha = repo.find_remote_sha(remote_branch_ref)
      else
        raise Error.new("Unexpected merge_rel (#{merge_rel})")
      end
      {"diffs" => diffs, "commit_sha" => commit_sha, "repo_obj" => repo}
    end

    def get_diffs_aux(repo,opts={})
      diffs = DiffSummary.new()
      #add any file that is untracked

      # repo.stage_changes()

      if opts[:remote_repo] and opts[:remote_repo_url]
        repo.add_remote(opts[:remote_repo],opts[:remote_repo_url])
      end

      unless opts[:no_fetch]
        repo.fetch(remote(opts[:remote_repo]))
      end

      local_branch      = repo.local_branch_name

      remote_branch_ref = remote_branch_ref(local_branch, opts)

      commit_shas = Hash.new
      merge_rel   = repo.merge_relationship(:remote_branch,remote_branch_ref, :ret_commit_shas => commit_shas)
      commit_sha  = nil

      if merge_rel == :equal
        commit_sha = commit_shas[:other_sha]
      elsif merge_rel == :no_remote_ref
        diffs = DiffSummary.new_version(repo)
        commit_sha = commit_shas[:local_sha]
      end

      # diffs = DiffSummary.diff_remote(repo,"remotes/#{remote_branch_ref}")
      diffs = DiffSummary.diff(repo,local_branch, remote_branch_ref)
      commit_sha = repo.find_remote_sha(remote_branch_ref)

      {"diffs" => diffs, "commit_sha" => commit_sha, "repo_obj" => repo, "status" => repo.local_summary() }
    end

    def pull_repo_changes_aux(repo,opts={})
      diffs = DiffSummary.new()

      if commit_sha = opts[:commit_sha]
        #no op if at commit_sha
        return diffs if commit_sha == repo.head_commit_sha()
      end

      if opts[:remote_repo] and opts[:remote_repo_url]
        repo.add_remote(opts[:remote_repo],opts[:remote_repo_url])
      end

      repo.fetch(remote(opts[:remote_repo]))

      local_branch = repo.local_branch_name
      remote_branch_ref = remote_branch_ref(local_branch,opts)

      if opts[:hard_reset]
        diffs = DiffSummary.diff(repo,local_branch, remote_branch_ref)
        repo.merge_theirs(remote_branch_ref)
        return({:diffs => diffs, :commit_sha => repo.head_commit_sha()})
      end

      # default commit in case it is needed
      repo.stage_and_commit("Commit prior to pull from remote") if repo.changed?

      #check if merge needed
      merge_rel = repo.merge_relationship(:remote_branch,remote_branch_ref)
      if merge_rel == :equal
        { :diffs => diffs, :commit_sha => repo.head_commit_sha() }
      elsif [:branchpoint,:local_ahead].include?(merge_rel)
        # TODO: right now just wiping out what is in repo
        diffs = DiffSummary.diff(repo,local_branch, remote_branch_ref)
        repo.merge_theirs(remote_branch_ref)
        { :diffs => diffs, :commit_sha => repo.head_commit_sha() }
      elsif merge_rel == :local_behind
        #see if any diffs between fetched remote and local branch
        #this has be done after commit
        diffs = DiffSummary.diff(repo,local_branch, remote_branch_ref)
        return diffs unless diffs.any_diffs?()

        begin
          repo.merge(remote_branch_ref)
        rescue Exception => e
          puts e
        end

        if commit_sha and commit_sha != repo.head_commit_sha()
          raise Error.new("Git synchronization problem: expected local head to have sha (#{commit_sha})")
        end

        { :diffs => diffs, :commit_sha => repo.head_commit_sha() }
      else
        raise Error.new("Unexpected merge_rel (#{merge_rel})")
      end
    end

    def remote(remote_repo=nil)
      remote_repo||"origin"
    end
    def remote_branch_ref(local_branch,opts={})
      "#{remote(opts[:remote_repo])}/#{opts[:remote_branch]||opts[:local_branch]||local_branch}"
    end

    def modules_dir(type,module_name,version=nil,opts={})
      if assembly_module = opts[:assembly_module]
        OsUtil.module_location_parts(type,module_name,version,opts)[0]
      elsif type == :component_module
        OsUtil.component_clone_location()
      elsif type == :service_module
        OsUtil.service_clone_location()
      elsif type == :test_module
        OsUtil.test_clone_location()
      else
        raise Error.new("Unexpected module type (#{type})")
      end
    end

    def local_repo_dir(type,module_name,version=nil,opts={})
      OsUtil.module_location(type,module_name,version,opts)
    end

    def adapter_class()
      Common::GritAdapter::FileAccess
    end

    def pp_module(repo)
      repo.repo_dir.gsub(Regexp.new("/$"),"").split("/").last
    end
  end; end
end; end; end


