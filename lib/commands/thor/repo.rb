module DTK::Client
  class Repo < CommandBaseThor
    def self.pretty_print_cols()
      PPColumns.get(:repo)
    end
    desc "list","List repos"
    def list()
      search_hash = SearchHash.new()
      search_hash.cols = pretty_print_cols()
      post rest_url("repo/list"), search_hash.post_body_hash()
    end

    desc "delete REPO-ID", "Delete repo"
    method_option :force, :aliases => '-f', :type => :boolean, :default => false
    def delete(repo_id)
      unless options.force?
        # Ask user if really want to delete repo, if not then return to dtk-shell without deleting
        return unless confirmation_prompt("Are you sure you want to delete repo '#{repo_id}'?")
      end

      post_body_hash = {:repo_id => repo_id}
      post rest_url("repo/delete"),post_body_hash
    end

    desc "sync REPO-ID", "Synchronize target repo from actual files"
    def sync(repo_id)
      post_body_hash = {:repo_id => repo_id}
      post rest_url("repo/synchronize_target_repo"),post_body_hash
    end

  end
end

