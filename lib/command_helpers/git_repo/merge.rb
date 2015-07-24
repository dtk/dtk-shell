module DTK::Client; class CommandHelper::GitRepo
  class Merge
    def initialize(repo, remote_branch_ref, opts = {})
      @repo = repo
      @remote_branch_ref = remote_branch_ref
      @local_branch = repo.local_branch_name
      # options
      @opts_commit_sha = opts[:commit_sha]
      @opts_force = opts[:force]
      @opts_merge_if_no_conflict = opts[:merge_if_no_conflict]
      @opts_ignore_dependency_merge_conflict = opts[:ignore_dependency_merge_conflict]
      @opts_full_module_name = opts[:full_module_name]
    end

    def self.merge(repo, remote_branch_ref, opts = {})
      new(repo, remote_branch_ref, opts).merge
    end

    def merge
      if @opts_force
        merge_force()
      else
        # check if merge needed
        merge_rel = merge_relationship()
        case merge_rel
          when :equal 
            response()
          when :branchpoint, :local_ahead
            merge_not_fast_forward()
          when :local_behind
            merge_simple()
          else
            raise Error.new("Unexpected merge_rel (#{merge_rel})")
        end
      end
    end

    private

    def merge_force
      diffs = diffs()
      @repo.merge_theirs(@remote_branch_ref)
      response(:diffs => diffs)
    end
    
    def merge_not_fast_forward
      if @opts_merge_if_no_conflict
        if any_conflicts?
          msg = 'Unable to do pull-dtkn merge without conflicts. Options are:'
          msg << " a) command 'pull-dtkn --force', but all local changes wil be lost or" 
          msg << " b) use command 'edit' to get in linux shell and directly use git commands."
          raise ErrorUsage.new(msg)
        else
          merge_simple
        end
      elsif @opts_force
        merge_force(repo, local_branch, remote_branch_ref)
      elsif @opts_ignore_dependency_merge_conflict
        custom_message = "Unable to do fast-forward merge. You can go to '#{@opts_full_module_name}' and pull with --force option but all changes will be lost." 
        response(:custom_message => :custom_message)
      else
        # this will only be reached if opts_merge_if_no_conflict is false 
        raise ErrorUsage.new('Unable to do fast-forward merge. You can use --force on pull-dtkn, but all local changes will be lost.')
      end
    end
    
    def merge_simple
      # see if any diffs between fetched remote and local branch
      # this has be done after commit
      diffs = diffs()
      return diffs unless diffs.any_diffs?()
      
      safe_execute do
        repo.merge(remote_branch_ref)
      end
      
      if commit_sha = @opts_commit_sha
          if commit_sha != repo.head_commit_sha()
            raise Error.new("Git synchronization problem: expected local head to have sha (#{commit_sha})")
          end
      end

      response(diffs)
    end
    
    def response(opts = {})
      { :diffs => diffs || opts[:diffs], :commit_sha => repo.head_commit_sha() }.merge(opts)
    end

    def merge_relationship
      @repo.merge_relationship(:remote_branch, @remote_branch_ref)    
    end

    def any_conflicts?
      # TODO: optimization is to combine this with mereg to have merge_if_no_conflics? 
      #       and if no conflicts just commit and merge --no-commit
      ret = nil
      begin
        repo.command('merge',['--no-commit', @remote_branch_ref])
      rescue ::Git::GitExecuteError
        ret = true
      ensure
        safe_execute do
          repo.command('merge',['--abort'])
        end
      end
      ret
    end
    
    def diffs
      DiffSummary.diff(@repo, @local_branch, @remote_branch_ref)
    end
    
    def safe_execute(&block)
      begin
        yield
      rescue Exception => e
        # TODO: this should be log message
        puts e
        nil
      end
    end
  end
end; end
