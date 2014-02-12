require 'rest_client'
require 'json'
require 'colorize'
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_from_base("command_helper")
dtk_require_common_commands('thor/task_status')
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
      [:utils]
    end

    def self.invisible_context()
      [:node]
    end

    # using extended_context when we want to use autocomplete from other context
    # e.g. we are in assembly/apache context and want to create-component we will use extended context to add 
    # component-templates to autocomplete
    def self.extended_context()
      {
        :context => {
          :create_component => "component_template",
          :create_node => "node_template",
          :create_component_dependency => "component_template"  
        },
        :command => {
          :edit_module => {
            :endpoint => "assembly", 
            :url => "assembly/info_about", 
            :opts => {:subtype=>"instance", :about=>"modules"}
          },
          :push_module_updates => {
            :endpoint => "assembly", 
            :url => "assembly/info_about", 
            :opts => {:subtype=>"instance", :about=>"modules"}
          }
        }
      }
    end

    # this includes children of children
    def self.all_children()
      # [:node, :component, :attribute]
      [:node]
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
            # ['delete-component',"delete-component COMPONENT-ID [-y]","# Delete component from assembly's node"],
            # ['list-attributes',"list-attributes","# List attributes associated with workspace's node."],
            # ['list-components',"list-components","# List components associated with workspace's node."]
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
            # ['delete',"delete NAME/ID [-y] ","# Delete component from workspace."],
            ['delete',"delete NODE-NAME/ID [-y] ","# Delete node, terminating it if the node has been spun up."],
            ['list',"list","# List nodes."]
          ],
          :component => [
            ['delete',"delete COMPONENT-NAME/ID [-y] ","# Delete component from workspace."],
            ['list-components',"list-components","# List components."]
          ],
          :utils => [
            ['get-netstats',"get-netstats","# Get netstats."],
            ['get-ps',"get-ps [--filter PATTERN]","# Get ps."],
            ['grep',"grep LOG-PATH NODE-ID-PATTERN GREP-PATTERN [--first]","# Grep log from multiple nodes. --first option returns first match (latest log entry)."],
            ['tail',"tail NODE-ID LOG-PATH [REGEX-PATTERN] [--more]","# Tail specified number of lines from log."]
          ]
        },
        :identifier_only => {
          :node      => [
            ['create-component',"create-component COMPONENT","# Add a component to the node."],
            ['delete-component',"delete-component COMPONENT-NAME [-y]","# Delete component from assembly's node"],
            ['info',"info","# Return info about node instance belonging to given workspace."],
            # ['link-attributes', "link-attributes TARGET-ATTR-TERM SOURCE-ATTR-TERM", "# Set TARGET-ATTR-TERM to SOURCE-ATTR-TERM."],
            ['list-attributes',"list-attributes","# List attributes associated with workspace's node."],
            ['list-components',"list-components","# List components associated with workspace's node."],
            ['set-attribute',"set-attribute ATTRIBUTE-NAME [VALUE] [-u]","# (Un)Set attribute value. The option -u will unset the attribute's value."],
            ['start', "start", "# Start node instance."],
            ['stop', "stop", "# Stop node instance."]
          ],
          :component => [
            ['info',"info","# Return info about component instance belonging to given node."],
            ['edit',"edit","# Edit component module related to given component."],
            # ['edit-dsl',"edit-dsl","# Edit component module dsl file related to given component."],
            ['link-components',"link-components ANTECEDENT-CMP-NAME [DEPENDENCY-NAME]","#Link components to satisfy component dependency relationship."],
            ['list-component-links',"list-component-links","# List component's links to other components."]
            #['unlink-components',"unlink-components SERVICE-TYPE","# Delete service link on component."]
            # ['create-attribute',"create-attribute SERVICE-TYPE DEP-ATTR ARROW BASE-ATTR","# Create an attribute to service link."],
          ],
          :attribute => [
            ['info',"info","# Return info about attribute instance belonging to given component."]
          ]
        }
      }, [:utils])
    end

    desc "WORKSPACE-NAME/ID cancel-task [TASK-ID]", "Cancel an executing task. If task id is omitted, the most recent executing task is canceled."
    def cancel_task(context_params)
      cancel_task_aux(context_params)
    end

    #desc "WORKSPACE-NAME/ID clear-tasks", "Clears the tasks that have been run already."
    #def clear_tasks(context_params)
    #  clear_tasks_aux(context_params)
    #end

    desc "WORKSPACE-NAME/ID converge [-m COMMIT-MSG]", "Converge workspace instance."
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string,
      :banner => "COMMIT-MSG",
      :desc => "Commit message" 
    def converge(context_params)
      converge_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID push-module-updates MODULE-NAME [--force]", "Push changes made to a component module in the workspace to its base component module."
    method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    def push_module_updates(context_params)
      push_module_updates_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID push-assembly-updates SERVICE-NAME/ASSEMBLY-NAME", "Push workspace instance to the designated assembly."
    def push_assembly_updates(context_params)
      workspace_id, qualified_assembly_name = context_params.retrieve_arguments([:workspace_id!,:option_1!],method_argument_names) 
      if qualified_assembly_name =~ /(^[^\/]*)\/([^\/]*$)/
        service_module_name, assembly_template_name = [$1,$2]
      else
        raise DtkError,"The term (#{qualified_assembly_name}) must have form SERVICE-NAME/ASSEMBLY-NAME"
      end
      response = promote_assembly_aux(:update,workspace_id, service_module_name, assembly_template_name)
      return response unless response.ok?
      @@invalidate_map << :assembly_template
      Response::Ok.new()
    end

    desc "WORKSPACE-NAME/ID create-assembly SERVICE-NAME ASSEMBLY-NAME [-p]", "Create a new assembly from the workspace instance in the designated service module."
   # The option -p will purge the workspace after assembly creation." 
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    def create_assembly(context_params)
      workspace_id, service_module_name, assembly_template_name = context_params.retrieve_arguments([:workspace_id!,:option_1!,:option_2!],method_argument_names)
      response = promote_assembly_aux(:create,workspace_id,service_module_name,assembly_template_name)
      return response unless response.ok?
      if options.purge?
        response = purge_aux(context_params)
        return response unless response.ok?
      end

      @@invalidate_map << :assembly_template
      @@invalidate_map << :service_module
      Response::Ok.new()
    end

    desc "WORKSPACE-NAME/ID create-attribute ATTRIBUTE-NAME [VALUE] [--type DATATYPE] [--required] [--dynamic]", "Create a new attribute and optionally assign it a value."
    method_option :required, :type => :boolean, :default => false
    method_option :dynamic, :type => :boolean, :default => false
    method_option :type, :aliases => "-t"
    def create_attribute(context_params)
      create_attribute_aux(context_params)
    end

    #only supported at node-level
    # using HIDE_FROM_BASE to hide this command from base context (dtk:/workspace>)
    desc "HIDE_FROM_BASE create-component NODE-NAME COMPONENT", "Add a component to a workspace."
    def create_component(context_params)
      response = create_component_aux(context_params)
      return response unless response.ok?

      @@invalidate_map << :assembly
      @@invalidate_map << :assembly_node

      response
    end

    # using ^^ before NODE-NAME to remove this command from workspace/node/node_id but show in workspace
    desc "WORKSPACE-NAME/ID create-node ^^NODE-NAME NODE-TEMPLATE", "Add (stage) a new node in the workspace."
    def create_node(context_params)
      response = create_node_aux(context_params)
      @@invalidate_map << :assembly_node

      return response
    end

    desc "WORKSPACE-NAME/ID link-components TARGET-CMP-NAME SOURCE-CMP-NAME [DEPENDENCY-NAME]","Link the target component to the source component."
    def link_components(context_params)
      link_components_aux(context_params)
    end

    desc "delete NAME/ID [-y]", ""
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete(context_params)
      if context_params.is_last_command_eql_to?(:node)
        response = delete_node_aux(context_params)
        @@invalidate_map << :assembly_node

        response
      elsif context_params.is_last_command_eql_to?(:component)
        response = delete_component_aux(context_params)
        return response unless response.ok?
        @@invalidate_map << :assembly_node_component
        
        response
      end
      # delete_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/workspace>)
    desc "HIDE_FROM_BASE delete-component COMPONENT-NAME [-y]","Delete component from the workspace."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_component(context_params)
      response = delete_component_aux(context_params)
      return response unless response.ok?
      
      @@invalidate_map << :assembly
      @@invalidate_map << :assembly_node
      @@invalidate_map << :assembly_node_component

      return response
    end

    # using ^^ before NODE-NAME to remove this command from workspace/node/node_id but show in workspace
    desc "WORKSPACE-NAME/ID delete-node ^^NODE-NAME [-y]","Delete node, terminating it if the node has been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_node(context_params)
      response = delete_node_aux(context_params)
      @@invalidate_map << :assembly_node

      return response
    end

    desc "WORKSPACE-NAME/ID unlink-components TARGET-CMP-NAME SOURCE-CMP-NAME [DEPENDENCY-NAME]", "Remove a component link."
    def unlink_components(context_params)
      unlink_components_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID edit-module MODULE-NAME", "Edit a component module used in the workspace."
    def edit_module(context_params)
      edit_module_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID edit-workflow", "Edit workflow"
    def edit_workflow(context_params)
      edit_workflow_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID edit-attributes", "Edit workspace's attributes."
    def edit_attributes(context_params)
      edit_attributes_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/workspace>)
    desc "HIDE_FROM_BASE get-netstats", "Get netstats"
    def get_netstats(context_params)
      get_netstats_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/workspace>)
    desc "HIDE_FROM_BASE get-ps [--filter PATTERN]", "Get ps"
    method_option :filter, :type => :boolean, :default => false, :aliases => '-f'
    def get_ps(context_params)
      get_ps_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/workspace>)
    desc "HIDE_FROM_BASE grep LOG-PATH NODES-ID-PATTERN GREP-PATTERN [--first]","Grep log from multiple nodes. --first option returns first match (latest log entry)."
    method_option :first, :type => :boolean, :default => false
    def grep(context_params)
      grep_aux(context_params)
    end
    
    desc "WORKSPACE-NAME/ID info", "Get info about content of the workspace."
    def info(context_params)
      info_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID link-attributes TARGET-ATTR SOURCE-ATTR", "Link the value of the target attribute to the source attribute."
    def link_attributes(context_params)
      link_attributes_aux(context_params)
    end

    #desc "WORKSPACE-NAME/ID list-attribute-mappings SERVICE-LINK-NAME/ID", "List attribute mappings associated with service link"
    #def list_attribute_mappings(context_params)
    #  list_attribute_mappings_aux(context_params)
    #end

    desc "list", ""
    def list(context_params)
      if context_params.is_last_command_eql_to?(:node)
        list_nodes_aux(context_params)
      end
    end

    desc "WORKSPACE-NAME/ID list-attributes [-f FORMAT] [--links]","List attributes associated with workspace."
    method_option :format,:aliases => '-f' 
    method_option :links, :type => :boolean, :default => false, :aliases => '-l'
    def list_attributes(context_params)
      list_attributes_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-components [--deps]","List components associated with workspace."
    method_option :deps, :type => :boolean, :default => false, :aliases => '-l'
    def list_components(context_params)
      list_components_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-nodes","List nodes associated with workspace."
    def list_nodes(context_params)
      list_nodes_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-component-links","List component links."
    def list_component_links(context_params)
      list_component_links_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-modules","List modules associated with workspace."
    def list_modules(context_params)
      list_modules_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-tasks","List tasks associated with workspace."
    def list_tasks(context_params)
      list_tasks_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID workflow-info", "Get the structure of the workflow associated with workspace."
    def workflow_info(context_params)
      workflow_info_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID list-violations", "Finds violations in the workspace that will prevent a converge operation."
    def list_violations(context_params)
      list_violations_aux(context_params)
    end

    # desc "WORKSPACE-NAME/ID promote-module-updates COMPONENT-MODULE-NAME [--force]", "Promotes changes made to component module in workspace to base component module"
    # method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    # def promote_module_updates(context_params)
    #   promote_module_updates_aux(context_params)
    # end

    desc "WORKSPACE-NAME/ID purge [-y]", "Purge the workspace, deleting and terminating any nodes that have been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def purge(context_params)
      purge_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID set-attribute ATTRIBUTE-NAME [VALUE] [-u]", "(Un)Set attribute value. The option -u will unset the attribute's value."
    method_option :unset, :aliases => '-u', :type => :boolean, :default => false
    def set_attribute(context_params)
      set_attribute_aux(context_params)
    end

#    desc "WORKSPACE-NAME/ID start [NODE-ID-PATTERN]", "Starts all workspace's nodes,  specific nodes can be selected via node id regex."
    desc "WORKSPACE-NAME/ID start [NODE-NAME]", "Starts all the workspace's nodes. A single node can be selected."
    def start(context_params)
      start_aux(context_params)
    end

#    desc "WORKSPACE-NAME/ID stop [NODE-ID-PATTERN]", "Stops all workspace's nodes, specific nodes can be selected via node id regex."
    desc "WORKSPACE-NAME/ID stop [NODE-NAME]", "Stops all the workspace's nodes. A single node can be selected."
    def stop(context_params)
      stop_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/workspace>)
    desc "HIDE_FROM_BASE tail NODES-IDENTIFIER LOG-PATH [REGEX-PATTERN] [--more]","Tail specified number of lines from log"
    method_option :more, :type => :boolean, :default => false
    def tail(context_params)
      tail_aux(context_params)
    end

    desc "WORKSPACE-NAME/ID task-status [--wait]", "Get the task status of the running or last running workspace task."
    method_option :wait, :type => :boolean, :default => false
    def task_status(context_params)
      task_status_aw_aux(context_params)
    end

  end
end

