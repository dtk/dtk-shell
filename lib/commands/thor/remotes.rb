module DTK::Client
  class Remotes < CommandBaseThor

    def self.valid_children()
      []
    end

    # REMOTE INTERACTION
    desc "push-remote", "Push local changes to remote git repository"
    method_option :force, :aliases => '--force', :type => :boolean, :default => false
    def push_remote(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "list-remotes", "List git remotes for given module"
    def list_remotes(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "add-remote", "Add git remote for given module"
    def add_remote(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "remove-remote", "Remove git remote for given module"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def remove_remote(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "make-active", "Make remote active one"
    def make_active(context_params)
      raise "NOT IMPLEMENTED"
    end

  end
end
