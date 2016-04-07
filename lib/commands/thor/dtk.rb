#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module DTK::Client

  # Following are descriptions of available commands
  class Dtk < CommandBaseThor

    # entities that are not available on root but later in n-context
    def self.additional_entities()
      ['component','attribute','utils','node','task','component-template','assembly','remotes']
    end

    if ::DTK::Configuration.get(:development_mode)
      desc "workspace","Sandbox for development and testing"
      def workspace
        # API descriptor, SYM_LINK!
      end
    end

    if ::DTK::Configuration.get(:development_mode)
      desc "target","Targets"
      def target
        # API descriptor, SYM_LINK!
      end
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

    if ::DTK::Configuration.get(:development_mode)
      desc "node-template", "Node Templates that map to machine images and containers."
      def node_template
        # API descriptor
      end
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

    if ::DTK::Configuration.get(:development_mode)
      desc "provider", "Manage infrastructure providers and deployment targets (ie: EC2 and us-east)"
      def provider
        # API descriptor
      end
    end

    # we do not need help here
    remove_task(:help,{:undefine => false})

  end
end
