require '/home/haris/DTK/dtk-client/lib/commands/assembly/thor.rb'

module DTK::Client

  # Following are descriptions of available commands 

  class DtkCommand < CommandBaseThor
    def self.pretty_print_cols()
      [:display_name, :id, :description]
    end

    # NOTE
    # Following methods are just api descriptors, invocation happens at "bin/dtk" entry point

    desc "assembly help","Part of dtk client used for assembly manipulation."
    def assembly
      # API descriptor
    end

    desc "dependency help","DESCRIPTION TO BE ADDED."
    def dependency
      # API descriptor
    end

    desc "library help", "Provides list of all libraries being used."
    def library
      # API descriptor
    end

    desc "module help", "Part of dtk client used for module manipulation."
    def module
      # API descriptor
    end

    desc "node help", "Add/Destroy/List available nodes."
    def node
      # API descriptor
    end    

    desc "node-group help", "Add/Destroy/List available groups of nodes."
    def node_group
      # API descriptor
    end    

    desc "repo help", "Part of dtk client which enables us to sync, destroy, view available repos."
    def repo
      # API descriptor
    end    

    desc "project help", "View available projects."
    def project
      # API descriptor
    end

    desc "service-module help", "Part of dtk client used for manipulation of service modules."
    def service_module
      # API descriptor
    end

    desc "state-change help",  "Follow the progress for given tasks."
    def state_change
      # API descriptor
    end

    desc "target help", "Form assembly template based on information on targted cluster."
    def target
      # API descriptor
    end

    desc "task", "Part of client used to view progress of task."
    def task
      # API descriptor
    end
  end
end

