require 'git'

module DTK
  module Client

    class GitAdapter

      attr_accessor :git_repo

      def initialize(repo_dir, branch = nil, opts = {})
        @git_repo = Git.open(repo_dir)
        @git_repo.branch(branch) if branch
      end

      def changed?
        !@git_repo.status.changed.empty?
      end

      def stage_changes()
        @git_repo.add(@git_repo.status.untracked().keys)
        @git_repo.add(@git_repo.status.changed().keys)
        @git_repo.remove(@git_repo.status.deleted().keys)
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

      #
      # Returns name of current branch (String)
      #
      def branch
        @git_repo.branches.local.first.name
      end

      def commit(commit_msg = "")
        @git_repo.commit(commit_msg)
      end

      def add_remote(name, url)
        @git_repo.add_remote(name, url)
      end

      def fetch(remote = 'origin')
        @git_repo.fetch(remote)
      end

      def self.clone(repo_url, target_path, branch)
        git_base = Git.clone(repo_url, target_path)
        git_base.branch(branch).checkout
        git_base
      end


    end
  end
end
