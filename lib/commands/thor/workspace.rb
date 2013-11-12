require 'rest_client'
require 'json'
require 'colorize'
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_from_base("command_helper")
dtk_require_common_commands('thor/task_status')
dtk_require_common_commands('thor/set_required_params')
dtk_require_common_commands('thor/edit')
dtk_require_common_commands('thor/purge_clone')
dtk_require_common_commands('thor/assembly_workspace')
# LOG_SLEEP_TIME_W   = DTK::Configuration.get(:tail_log_frequency)

module DTK::Client
  class Workspace < CommandBaseThor
    no_tasks do
      include TaskStatusMixin
      include SetRequiredParamsMixin
      include EditMixin
      include PurgeCloneMixin
      include AssemblyWorkspaceMixin
      
      def get_workspace_name(workspace_id)
        get_name_from_id_helper(workspace_id)
      end
    end

    def self.whoami()
      return :workspace, "assembly/list", {:subtype  => 'instance'}
    end

    def self.pretty_print_cols()
      PPColumns.get(:assembly)
    end

    def self.valid_children()
      [:node, :utils]
    end

    # using extended_context when we want to use autocomplete from other context
    # e.g. we are in assembly/apache context and want to create-component we will use extended context to add 
    # component-templates to autocomplete
    def self.extended_context()
      {:create_component => "component_template", :create_node => "node_template", :create_component_dependency => "component_template"}
    end

    # this includes children of children
    def self.all_children()
      [:node, :component, :attribute]
      # [:utils]
    end

    def self.multi_context_children()
      [[:utils],[:node, :utils]]
    end

    def self.valid_child?(name_of_sub_context)
      return Workspace.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      get_cached_response(:workspace, "assembly/list_with_workspace", {})
    end

    # TODO: Hack which is necessery for the specific problem (DTK-541), something to reconsider down the line
    # at this point not sure what would be clenear solution

    # :all             => include both for commands with command and identifier
    # :command_only    => only on command level
    # :identifier_only => only on identifier level for given entity (command)
    #
    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :all => {
          :node      => [
            ['delete-component',"delete-component COMPONENT-ID [-y]","# Delete component from assembly's node"],
            ['list-components',"list-components","# List components associated with workspace's node."],
            ['list-attributes',"list-attributes","# List attributes associated with workspace's node."]
          ],
          :component => [
            ['list-attributes',"list-attributes","# List attributes associated with given component."]
          ]
        },
        :command_only => {
          :attribute => [
            ['list-attributes',"list-attributes","# List attributes."]
          ],
          :node => [
            ['delete',"delete NAME/ID [-y] ","# Delete node, terminating it if the node has been spun up."],
            ['list-nodes',"list-nodes ","# List nodes."]
          ],
          :component => [
            ['list-components',"list-components","# List components."],
            ['delete',"delete NAME/ID [-y] ","# Delete component from workspace."]
          ],
          :utils => [
            ['get-netstats',"get-netstats","# Get netstats."],
            ['get-ps',"get-ps [--filter PATTERN]","# Get ps."],
            ['tail',"tail NODE-ID LOG-PATH [REGEX-PATTERN] [--more]","# Tail specified number of lines from log."],
            ['grep',"grep LOG-PATH NODE-ID-PATTERN GREP-PATTERN [--first]","# Grep log from multiple nodes. --first option returns first match (latest log entry)."]
          ]
        },
        :identifier_only => {
          :node      => [
            ['create-component',"create-component COMPONENT-TEMPLATE-NAME/ID","# Add component to node. Default workflow order position is at the end."],
            ['info',"info","# Return info about node instance belonging to given workspace."],
            ['link-attributes', "link-attributes TARGET-ATTR-TERM SOURCE-ATTR-TERM", "# Set TARGET-ATTR-TERM to SOURCE-ATTR-TERM."]
          ],
          :component => [
            ['info',"info","# Return info about component instance belonging to given node."],
            ['list-service-links',"list-service-links","# List service links for component."],
            ['link-components',"link-components ANTECEDENT-CMP-NAME [DEPENDENCY-NAME]","#Link components to satisfy component dependency relationship."],
            ['unlink-components',"unlink-components SERVICE-TYPE","# Delete service link on component."],
            # ['create-attribute',"create-attribute SERVICE-TYPE DEP-ATTR ARROW BASE-ATTR","# Create an attribute to service link."],
            ['list-attribute-mappings',"list-attribute-mappings SERVICE-TYPE","# List attribute mappings assocaited with service link."],
            ['edit',"edit","# Edit component module related to given component."],
            ['edit-dsl',"edit-dsl","# Edit component module dsl file related to given component."]
          ],
          :attribute => [
            ['info',"info","# Return info about attribute instance belonging to given component."]
          ]
        }
      }, [:utils])
    end


    desc "WORKSPACE-NAME/ID cancel-task TASK_ID", "Cancels task."
    def cancel_task(context_params)
      cancel_aw_task_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID converge [-m COMMIT-MSG]", "Converges workspace instance."
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string,
      :banner => "COMMIT-MSG",
      :desc => "Commit message" 
    def converge(context_params)
      converge_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID promote-module-updates COMPONENT-MODULE-NAME [--force]", "Promotes changes made to component module in assembly to base component module"
    method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    def promote_module_updates(context_params)
      promote_module_updates_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID create-assembly SERVICE-MODULE-NAME ASSEMBLY-TEMPLATE-NAME [-p]", "Creates a new assembly template or updates existing one from workspace instance. -p will purge workspace after templaet creation" 
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    def create_assembly(context_params)
      response = create_assembly_aux(context_params)
      @@invalidate_map << :assembly_template

      return response
    end

    # will leave this commented for now, need to check with Rich if we need this
    # desc "WORKSPACE-NAME/ID create-attribute ATTRIBUTE-NAME [VALUE] [--required] [--dynamic]", "Create attribute and optionally assign it a value"
    # method_option :required, :type => :boolean, :default => false
    # method_option :dynamic, :type => :boolean, :default => false
    # def create_attribute(context_params)
    #   create_attribute_aux(context_params)
    # end

    desc "create-component COMPONENT-TEMPLATE-NAME/ID", "Add component template to assembly node."
    def create_component(context_params)
      create_component_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID create-node ASSEMBLY-NODES-NAME NODE-TEMPLATE", "Add (stage) a new node to workspace"
    def create_node(context_params)
      response = create_node_aux(context_params)
      @@invalidate_map << :assembly_node

      return response
    end

    desc "WORKSPACE-NAME/ID link-components DEPENDENT-CMP-NAME ANTECEDENT-CMP-NAME [DEPENDENCY-NAME]","#Link components to satisfy component dependency relationship."
    def link_components(context_params)
      link_components_aux(context_params)
    end

    desc "delete NAME/ID [-y]", ""
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete(context_params)
      delete_aux(context_params)
    end

    desc "delete-component COMPONENT-ID","Delete component from workspace"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_component(context_params)
      response = delete_component_aux(context_params)
      return response unless response.ok?
      @@invalidate_map << :assembly_node_component

      return response
    end

    desc "WORKSPACE-NAME/ID delete-node NAME/ID [-y]","Delete node, terminating it if the node has been spun up"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_node(context_params)
      response = delete_node_aux(context_params)
      @@invalidate_map << :assembly_node

      return response
    end

    desc "WORKSPACE-NAME/ID unlink-components SERVICE-LINK-ID", "Delete a service link"
    def unlink_components(context_params)
      unlink_components_aux(context_params)
    end

    desc "COMPONENT-NAME/ID edit","Edit component module related to given component."
    def edit(context_params)
      component_edit_aux(context_params)
    end

    desc "COMPONENT-NAME/ID edit-dsl","Edit component module related to given component."
    def edit_dsl(context_params)
      context_params.forward_options( { :edit_dsl => true})
      component_edit_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID edit-module COMPONENT-MODULE-NAME", "Edit component module used by the workspace"
    def edit_module(context_params)
      edit_module_aux(context_params)
    end

    desc "get-netstats [-y]", "Get netstats"
    def get_netstats(context_params)
      get_netstats_aux(context_params)
    end

    desc "get-ps [--filter PATTERN]", "Get ps"
    method_option :filter, :type => :boolean, :default => false, :aliases => '-f'
    def get_ps(context_params)
      get_ps_aux(context_params)
    end

    desc "grep LOG-PATH NODES-ID-PATTERN GREP-PATTERN [--first]","Grep log from multiple nodes. --first option returns first match (latest log entry)."
    method_option :first, :type => :boolean, :default => false
    def grep(context_params)
      grep_aux(context_params)
    end
    
    desc "WORKSPACE-NAME/ID info", "Return info about workspace instance identified by name/id"
    def info(context_params)
      info_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID link-attributes TARGET-ATTR-TERM SOURCE-ATTR-TERM", "Set TARGET-ATTR-TERM to SOURCE-ATTR-TERM"
    def link_attributes(context_params)
      link_attributes_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-attributes","List attributes associated with workspace."
    def list_attributes(context_params)
      list_attributes_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-attribute-mappings SERVICE-LINK-NAME/ID", "List attribute mappings associated with service link"
    def list_attribute_mappings(context_params)
      list_attribute_mappings_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-components","List components associated with workspace."
    def list_components(context_params)
      list_components_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-nodes","List nodes associated with workspace."
    def list_nodes(context_params)
      list_nodes_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-service-links","List service links"
    def list_service_links(context_params)
      list_service_links_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-tasks","List tasks associated with workspace."
    def list_tasks(context_params)
      list_tasks_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID workflow-info", "Provides the structure of the assembly's workflow"
    def workflow_info(context_params)
      workflow_info_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-violations", "Finds violations in workspace that will prevent a converge operation"
    def list_violations(context_params)
      list_violations_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID purge [-y]", "Purge the workspace, deleting and terminating any nodes that have been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def purge(context_params)
      purge_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID set-attribute ATTRIBUTE-NAME/ID VALUE [-u] [-r]", "Set workspace attribute value(s). -u will unset attribute. -r will set only required attributes"
    method_option :unset, :aliases => '-u', :type => :boolean, :default => false
    method_option :required, :aliases => '-r', :type => :boolean, :default => false
    def  set_attribute(context_params)
      set_attribute_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID start [NODE-ID-PATTERN]", "Starts all workspace's nodes,  specific nodes can be selected via node id regex."
    def start(context_params)
      start_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID stop [NODE-ID-PATTERN]", "Stops all workspace's nodes, specific nodes can be selected via node id regex."
    def stop(context_params)
      stop_aux(context_params)
    end

    desc "tail NODES-IDENTIFIER LOG-PATH [REGEX-PATTERN] [--more]","Tail specified number of lines from log"
    method_option :more, :type => :boolean, :default => false
    def tail(context_params)
      tail_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID task-status [--wait]", "Task status of running or last workspace task"
    method_option :wait, :type => :boolean, :default => false
    def task_status(context_params)
      task_status_aw_aux(context_params)
    end

  end
end

