module DTK::Client
  class Remotes < CommandBaseThor

    def self.valid_children()
      []
    end

    # REMOTE INTERACTION

    desc "list-remotes", "List git remotes for given module"
    def list_remotes(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "add-remote", "Add git remote for given module"
    def add_remote(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "remote-remote", "Remove git remote for given module"
    def remove_remote(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "make-active", "Make remote active one"
    def make_active(context_params)
      raise "NOT IMPLEMENTED"
    end





  end
end
