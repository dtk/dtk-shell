
module DTK::Client

  # Following are descriptions of available commands 
  class Dtk < CommandBaseThor

    # entities that are not available on root but later in n-context
    def self.additional_entities()
      ['target','component','attribute']
    end

    desc "workspace","Manipulate provided workspace"
    def workspace
      # API descriptor, SYM_LINK!
    end
    

    # NOTE
    # Following methods are just api descriptors, invocation happens at "bin/dtk" entry point
    desc "account","Commands to execute, query and manipulate account information."
    def account
      # API descriptor
    end

    desc "assembly","Commands to execute, query and manipulate assembly instances."
    def assembly
      # API descriptor
    end

    desc "assembly-template","Commands to stage or launch new assemblies and query assembly templates."
    def assembly_template
      # API descriptor
    end

    #TODO: not exposed 
    #desc "dependency","DESCRIPTION TO BE ADDED."
    #def dependency
    #  # API descriptor
    #end

    desc "library", "Commands to list and query libraries."
    def library
      # API descriptor
    end

    desc "module", "Commands to create, query, import and export component modules."
    def module
      # API descriptor
    end

    desc "node", "Commands to list, query, and delete/destroy node instances."
    def node
      # API descriptor
    end    

    desc "node-group", "Add/Destroy/List available groups of nodes."
    def node_group
      # API descriptor
    end

    desc "node-template", "Commands to list and query node templates."
    def node_template
      # API descriptor
    end

    desc "component-template","Commands to list and query component templates."
    def component_template
      # API descriptor
    end

    #TODO: remove
    #desc "repo", "Part of dtk client which enables us to sync, destroy, view available repos."
    #def repo
    #  # API descriptor
    #end    

    #TODO: not supported yet
    #desc "project", "View available projects."
    #def project
    #  # API descriptor
    #end

    desc "service", "Commands to create, query, import and export service modules."
    def service
      # API descriptor
    end

    # TODO: not supported yet
    # desc "state-change",  "Commands to query what has been changed."
    # def state_change
    #   # API descriptor
    # end

    desc "task", "Commands to list and view current and past tasks."
    def task
      # API descriptor
    end

    desc "developer", "DEV tools only available to developers."
    def developer
      # API descriptor
    end
    

    desc "provider", "DTK providers"
    def provider
      # API descriptor
    end

    # we do not need help here
    remove_task(:help,{:undefine => false})

  end
end

