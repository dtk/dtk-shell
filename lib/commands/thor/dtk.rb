
module DTK::Client

  # Following are descriptions of available commands
  class Dtk < CommandBaseThor

    # entities that are not available on root but later in n-context
    def self.additional_entities()
      ['component','attribute','utils','node','task','component-template','assembly','remotes']
    end

    desc "workspace","Sandbox for development and testing"
    def workspace
      # API descriptor, SYM_LINK!
    end

    desc "target","Targets"
    def target
      # API descriptor, SYM_LINK!
    end


    # NOTE
    # Following methods are just api descriptors, invocation happens at "bin/dtk" entry point
    desc "account","Account management for accessing DTK server"
    def account
      # API descriptor
    end

    desc "service","Assembly instances that have been deployed via DTK."
    def service
      # API descriptor
    end

    # desc "assembly","Commands to stage or launch new assemblies and query assembly templates."
    # def assembly
    #   # API descriptor
    # end

    #TODO: not exposed
    #desc "dependency","DESCRIPTION TO BE ADDED."
    #def dependency
    #  # API descriptor
    #end

    # desc "library", "Commands to list and query libraries."
    # def library
    #   # API descriptor
    # end

    desc "component-module", "DTK definitions for modeling/defining individual configuration components."
    def component_module
      # API descriptor
    end

    desc "test-module", "DTK definitions for modeling/defining individual test components."
    def test_module
      # API descriptor
    end

    # desc "node", "Commands to list, query, and delete/destroy node instances."
    # def node
    #   # API descriptor
    # end

    # desc "node-group", "Add/Destroy/List available groups of nodes."
    # def node_group
    #   # API descriptor
    # end

    desc "node-template", "Node Templates that map to machine images and containers."
    def node_template
      # API descriptor
    end

    # desc "component-template","Commands to list and query component templates."
    # def component_template
    #   # API descriptor
    # end

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

    desc "service-module", "DTK definitions for modeling/defining distributed applications and services."
    def service_module
      # API descriptor
    end

    # TODO: not supported yet
    # desc "state-change",  "Commands to query what has been changed."
    # def state_change
    #   # API descriptor
    # end

    # desc "task", "Commands to list and view current and past tasks."
    # def task
    #   # API descriptor
    # end

    if ::DTK::Configuration.get(:development_mode)
      desc "developer", "DEV tools only available to developers."
      def developer
        # API descriptor
      end
    end


    desc "provider", "Manage infrastructure providers and deployment targets (ie: EC2 and us-east)"
    def provider
      # API descriptor
    end

    # we do not need help here
    remove_task(:help,{:undefine => false})

  end
end

