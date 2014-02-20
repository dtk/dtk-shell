require 'git'

module DTK
  module Client
    class GitAdapter
      attr_accessor :git_repo

      def initialize(repo_dir, branch = nil, opts = {})
        @git_repo = Git.init(repo_dir)
        @git_repo.branch(branch) if branch
      end

      def changed?
        (!(@git_repo.status.changed.empty? && @git_repo.status.untracked.empty? && @git_repo.status.deleted.empty?) || staged_commits?)
      end

      def stage_changes()
        @git_repo.add(@git_repo.status.untracked().keys)
        @git_repo.add(@git_repo.status.changed().keys)
        @git_repo.status.deleted().each do |file, status|
          # this indicates that change has not been staged
          if status.stage
            @git_repo.remove(file)
          end
        end
      end

      def print_status()
        changes = [@git_repo.status.changed().keys, @git_repo.status.untracked().keys, @git_repo.status.deleted().keys]
        puts "\nModified files:\n".colorize(:green) unless changes[0].empty?
        changes[0].each { |item| puts "\t#{item}" }
        puts "\nAdded files:\n".colorize(:yellow) unless changes[1].empty?
        changes[1].each { |item| puts "\t#{item}" }
        puts "\nDeleted files:\n".colorize(:red) unless changes[2].empty?
        changes[2].each { |item| puts "\t#{item}" }
        puts ""
      end

      def diff_summary(local_branch, remote_reference)
        branch_local_obj  = @git_repo.branches.local.find { |b| b.name == local_branch }
        branch_remote_obj = @git_repo.branches.remote.find{|r| "#{r.remote}/#{r.name}" == remote_reference }

        if branch_local_obj && branch_remote_obj

          difference = @git_repo.diff(branch_local_obj, branch_remote_obj)

          files_modified = difference.stats[:files] ? difference.stats[:files].keys.collect { |file| { :path => file }} : []
          {
            :files_modified => files_modified
          }
        else
          raise Error.new("Error finding branches: local branch '#{local_branch}' (found: #{!branch_local_obj.nil?}), remote branch '#{remote_reference}' (found: #{!branch_remote_obj.nil?})")
        end
      end

      def local_summary()
        {
          :files_added => @git_repo.status.untracked().keys.collect { |file| { :path => file }},
          :files_modified => @git_repo.status.changed().keys.collect { |file| { :path => file }},
          :files_deleted => @git_repo.status.deleted().keys.collect { |file| { :path => file }}
        }
      end

      def new_version()
        {
          :files_added => @git_repo.status.untracked().keys.collect { |file| { :path => file }}
        }
      end

      def commit(commit_msg = "")
        @git_repo.commit(commit_msg)
      end

      def add_remote(name, url)
        unless is_there_remote?(name)
          @git_repo.add_remote(name, url)
        end
      end

      def fetch(remote = 'origin')
        @git_repo.fetch(remote)
      end

      def rev_list(commit_sha)
        git_command('rev-list', commit_sha)
      end

      def staged_commits?()
        response = git_command('diff','--cached')
        !response.empty?
      end

      def rev_list_contains?(container_sha, index_sha)
        results = rev_list(container_sha)
        !results.split("\n").grep(index_sha).empty?
      end

      def head_commit_sha()
        current_branch.gcommit.sha
      end

      def find_remote_sha(ref)
        remote = @git_repo.branches.remote.find{|r| "#{r.remote}/#{r.name}" == ref}
        remote.gcommit.sha
      end

      def merge_relationship(type, ref, opts={})
        ref_remote, ref_branch = ref.split('/')
        # fetch remote branch
        fetch(ref_remote) if opts[:fetch_if_needed]
        

        git_reference = case type
          when :remote_branch
            @git_repo.branches.remote.find { |r| "#{r.remote}/#{r.name}" == ref } 
          when :local_branch
            # DEBUG SNIPPET >>>> REMOVE <<<<
            raise "HARIS Exception ref #{ref}"
            @git_repo.branches.find { |b| b.name == ref }
          else 
            raise Error.new("Illegal type parameter (#{type}) passed to merge_relationship") 
        end

        local_sha = current_branch.gcommit.sha

        opts[:ret_commit_shas][:local_sha] = local_sha if opts[:ret_commit_shas]
      
        unless git_reference
          return :no_remote_ref if type.eql?(:remote_branch)

          raise Error.new("Cannot find git ref '#{ref}'")
        end

        git_reference_sha = git_reference.gcommit.sha
        opts[:ret_commit_shas][:other_sha] = git_reference_sha if opts[:ret_commit_shas]

        # shas can be different but content the same
        if git_reference_sha.eql?(local_sha) || !any_differences?(local_sha, git_reference_sha)
          :equal
        else
          if rev_list_contains?(local_sha, git_reference_sha)
            :local_ahead
          elsif rev_list_contains?(git_reference_sha, local_sha)
            :local_behind
          else
            :branchpoint
          end
        end
      end

      def push(remote_branch_ref)
        remote, remote_branch = remote_branch_ref.split('/')
        push_with_remote(remote, remote_branch)
      end
      
      def push_with_remote(remote, remote_branch)
        branch_for_push = "#{current_branch_name}:refs/heads/#{remote_branch||current_branch_name}"
        @git_repo.push(remote, branch_for_push)
      end

      def add_file(file_rel_path, content)
        content ||= String.new
        file_path = "#{@git_repo.dir}/#{file_rel_path}"
        File.open(file_path,"w"){|f|f << content}
        @git_repo.add(file_path)
      end

      def pull_remote_to_local(remote_branch, local_branch, remote='origin')
        @git_repo.pull(remote,"#{remote_branch}:#{local_branch}")
      end

      def merge(remote_branch_ref)
        @git_repo.merge(remote_branch_ref)
      end

      def self.clone(repo_url, target_path, branch)
        git_base = Git.clone(repo_url, target_path)
        git_base.branch(branch).checkout unless branch.nil?
        git_base
      end

      def repo_dir
        @git_repo.dir.path
      end

      def current_branch_name
        current_branch.name
      end

      def current_branch
        @git_repo.branches.local.find { |b| b.current }
      end

    private

      def is_there_remote?(remote_name)
        @git_repo.remotes.find { |r| r.name == remote_name }
      end

      def any_differences?(sha1, sha2)
        @git_repo.diff(sha1, sha2).size > 0
      end

      def git_command(cmd, opts=[])
        ENV['GIT_DIR'] = "#{@git_repo.dir.path}/.git"
        ENV['GIT_INDEX_FILE'] = @git_repo.index.path

        path = @git_repo.dir.path

        opts = [opts].flatten.join(' ')

        response = `git #{cmd} #{opts}`.chomp

        ENV.delete('GIT_DIR')
        ENV.delete('GIT_INDEX_FILE')

        return response
      end

    end
  end
end
