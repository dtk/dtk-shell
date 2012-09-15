
module DTK::Client

  # Following are descriptions of available commands 
  class Dtk < CommandBaseThor

    

    # NOTE
    # Following methods are just api descriptors, invocation happens at "bin/dtk" entry point

    desc "assembly","Commands to execute, query and manipulate assembly instances."
    def assembly
      # API descriptor
    end

    desc "assembly-template","Work with assembly templates."
    def assembly_template
      # API descriptor
    end

    desc "dependency","DESCRIPTION TO BE ADDED."
    def dependency
      # API descriptor
    end

    desc "library", "Provides list of all libraries being used."
    def library
      # API descriptor
    end

    desc "module", "Part of dtk client used for module manipulation."
    def module
      # API descriptor
    end

    desc "module-component", "Work with module component templates."
    def module_component
      # API descriptor
    end

    desc "node", "Add/Destroy/List available nodes."
    def node
      # API descriptor
    end    

    desc "node-group", "Add/Destroy/List available groups of nodes."
    def node_group
      # API descriptor
    end

    desc "node-template", "Work with node templates."
    def node_template
      # API descriptor
    end

    desc "component-template","Work with component templates."
    def component_template
      # API descriptor
    end

    desc "repo", "Part of dtk client which enables us to sync, destroy, view available repos."
    def repo
      # API descriptor
    end    

    desc "project", "View available projects."
    def project
      # API descriptor
    end

    desc "service-module", "Part of dtk client used for manipulation of service modules."
    def service_module
      # API descriptor
    end

    desc "state-change",  "Follow the progress for given tasks."
    def state_change
      # API descriptor
    end

    desc "target", "Form assembly template based on information on targted cluster."
    def target
      # API descriptor
    end

    desc "task", "Part of client used to view progress of task."
    def task
      # API descriptor
    end
    
    # we do not need help here
    remove_task(:help,{:undefine => false})

  end
end

