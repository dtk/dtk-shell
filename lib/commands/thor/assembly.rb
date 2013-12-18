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
LOG_SLEEP_TIME   = DTK::Configuration.get(:tail_log_frequency)
DEBUG_SLEEP_TIME = DTK::Configuration.get(:debug_task_frequency)

# regex: (context_params.retrieve_arguments\([a-z\[\]:_,0-9!]+)
# replace: $1,method_argument_names

module DTK::Client
  class Assembly < CommandBaseThor

    no_tasks do
      include TaskStatusMixin
      include SetRequiredParamsMixin
      include EditMixin
      include PurgeCloneMixin
      include AssemblyWorkspaceMixin

      def get_assembly_name(assembly_id)
        get_name_from_id_helper(assembly_id)
      end
    end

    def self.whoami()
      return :assembly, "assembly/list", {:subtype  => 'instance'}
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
    end

    def self.multi_context_children()
      [[:utils],[:node, :utils]]
    end

    def self.valid_child?(name_of_sub_context)
      return Assembly.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      get_cached_response(:assembly, "assembly/list", {})
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
          # :node => [
            # ['delete-component',"delete-component COMPONENT-ID","# Delete component from assembly's node"],
            # ['list-components',"list-components","# List components associated with assembly's node."],
            # ['list-attributes',"list-attributes","# List attributes associated with assembly's node."]
          # ],
          :component => [
            ['list-attributes',"list-attributes","# List attributes associated with given component."]
=begin
TODO: overlaps with different meaning
            ['create-attribute',"create-attribute SERVICE-TYPE DEP-ATTR ARROW BASE-ATTR","# Create an attribute to service link."],
=end
          ]
        },
        :command_only => {
          :attribute => [
            ['list-attributes',"list-attributes","# List attributes."]
          ],
          :node => [
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
            ['delete-component',"delete-component COMPONENT-ID","# Delete component from assembly's node"],
            ['info',"info","# Return info about node instance belonging to given workspace."],
            # ['link-attributes', "link-attributes TARGET-ATTR-TERM SOURCE-ATTR-TERM", "# Set TARGET-ATTR-TERM to SOURCE-ATTR-TERM."],
            ['list-attributes',"list-attributes","# List attributes associated with assembly's node."],
            ['list-components',"list-components","# List components associated with assembly's node."],
            ['start', "start", "# Start node instance."],
            ['stop', "stop", "# Stop node instance."]
          ],
          :component => [
            ['info',"info","# Return info about component instance belonging to given node."],
            ['edit',"edit","# Edit component module related to given component."],
            ['edit-dsl',"edit-dsl","# Edit component module dsl file related to given component."],
            ['link-components',"link-components ANTECEDENT-CMP-NAME [DEPENDENCY-NAME]","#Link components to satisfy component dependency relationship."],
            ['list-component-links',"list-component-links","# List component's links to other components."],
            ['unlink-components',"unlink-components SERVICE-TYPE","# Delete service link on component."]
          ],
          :attribute => [
            ['info',"info","# Return info about attribute instance belonging to given component."]
          ]
        }
      })
    end

    desc "ASSEMBLY-NAME/ID start [NODE-NAME]", "Starts all the assembly's nodes. A single node can be selected."
    def start(context_params)
      start_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID stop [NODE-NAME]", "Stops all the assembly's nodes. A single node can be selected."
    def stop(context_params)
      stop_aux(context_params)
    end


    desc "ASSEMBLY-NAME/ID cancel-task [TASK_ID]", "Cancels an executing task.  If task id is omitted, this command cancels the most recent executing task."
    def cancel_task(context_params)
      cancel_task_aux(context_params)
    end

    #desc "ASSEMBLY-NAME/ID clear-tasks", "Clears the tasks that have been run already."
    #def clear_tasks(context_params)
    #  clear_tasks_aux(context_params)
    #end

    desc "ASSEMBLY-NAME/ID create-assembly SERVICE-NAME ASSEMBLY-NAME", "Create a new assembly from this assembly instance in the designated service module."
    def create_assembly(context_params)
      assembly_id, service_module_name, assembly_template_name = context_params.retrieve_arguments([:assembly_id!,:option_1!,:option_2!],method_argument_names)
      response = promote_assembly_aux(:create,assembly_id,service_module_name,assembly_template_name)
      return response unless response.ok?

      @@invalidate_map << :assembly_template
      @@invalidate_map << :service_module
      Response::Ok.new()
    end
    
    desc "ASSEMBLY-NAME/ID converge [-m COMMIT-MSG]", "Converge assembly instance."
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string,
      :banner => "COMMIT-MSG",
      :desc => "Commit message" 
    def converge(context_params)
      converge_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID push-assembly-updates SERVICE-NAME/ASSEMBLY-NAME", "Push workspace instance to the designated assembly."
    def push_assembly_updates(context_params)
      assembly_id, qualified_assembly_name = context_params.retrieve_arguments([:assembly_id!,:option_1!],method_argument_names) 
      if qualified_assembly_name =~ /(^[^\/]*)\/([^\/]*$)/
        service_module_name, assembly_template_name = [$1,$2]
      else
        raise DtkError,"The term (#{qualified_assembly_name}) must have form SERVICE-NAME/ASSEMBLY-NAME"
      end
      response = promote_assembly_aux(:update,assembly_id, service_module_name, assembly_template_name)
      return response unless response.ok?
      @@invalidate_map << :assembly_template
      Response::Ok.new()
    end

    desc "ASSEMBLY-NAME/ID push-module-updates MODULE-NAME [--force]", "Push changes made to a component module in the assembly to its base component module."
    method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    def push_module_updates(context_params)
      push_module_updates_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID edit-module MODULE-NAME", "Edit a component module used in the assembly."
    def edit_module(context_params)
      edit_module_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID edit-workflow", "Edit assembly's workflow."
    def edit_workflow(context_params)
      edit_workflow_aux(context_params)
    end

    # desc "ASSEMBLY-NAME/ID promote-module-updates COMPONENT-MODULE-NAME [--force]", "Promotes changes made to component module in assembly to base component module"
    # method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    # def promote_module_updates(context_params)
    #   promote_module_updates_aux(context_params)
    # end

=begin
TODO: will put in dot release and will rename to 'extend'
    desc "ASSEMBLY-NAME/ID add EXTENSION-TYPE [-n COUNT]", "Adds a sub assembly template to the assembly"
    method_option "count",:aliases => "-n" ,
      :type => :string, #integer 
      :banner => "COUNT",
      :desc => "Number of sub-assemblies to add"
    def add_node(context_params)
      assembly_id,service_add_on_name = context_params.retrieve_arguments([:assembly_id!,:option_1!],method_argument_names)

      # create task
      post_body = {
        :assembly_id => assembly_id,
        :service_add_on_name => service_add_on_name
      }

      post_body.merge!(:count => options.count) if options.count

      response = post rest_url("assembly/add__service_add_on"), post_body
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly

      return response
    end

    desc "ASSEMBLY-NAME/ID possible-extensions", "Lists the possible extensions to the assembly" 
    def possible_extensions(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)

      post_body = {
        :assembly_id => assembly_id
      }
      response = post(rest_url("assembly/list_possible_add_ons"),post_body)
      response.render_table(:service_add_on)
    end
=end

    desc "ASSEMBLY-NAME/ID task-status [--wait]", "Get the task status of the running or last running assembly task."
    method_option :wait, :type => :boolean, :default => false
    def task_status(context_params)
      task_status_aw_aux(context_params)
    end

=begin
    desc "ASSEMBLY-NAME/ID run-smoketests", "Run smoketests associated with assembly instance"
    def run_smoketests(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)
      post_body = {
        :assembly_id => assembly_id
      }
      # create smoke test
      response = post rest_url("assembly/create_smoketests_task"), post_body
      return response unless response.ok?
      # execute
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end
=end

    desc "ASSEMBLY-NAME/ID list-nodes","List nodes associated with assembly."
    def list_nodes(context_params)
      list_nodes_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID list-component-links","List component links."
    def list_component_links(context_params)
      list_component_links_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID list-components","List components associated with assembly."
    def list_components(context_params)
      list_components_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID list-attributes [-f FORMAT]","List attributes associated with assembly."
    method_option "format",:aliases => "-f" 
    def list_attributes(context_params)
      list_attributes_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID list-tasks","List tasks associated with assembly."
    def list_tasks(context_params)
      list_tasks_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID list-violations", "Finds violations in the assembly that will prevent a converge operation."
    def list_violations(context_params)
      list_violations_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID workflow-info", "Get the structure of the workflow associated with assembly."
    def workflow_info(context_params)
      workflow_info_aux(context_params)
    end

    desc "[ASSEMBLY-NAME/ID] list","List assemblies."
    def list(context_params)
      assembly_id, node_id, component_id, attribute_id, about = context_params.retrieve_arguments([:assembly_id,:node_id,:component_id,:attribute_id,:option_1],method_argument_names)
      detail_to_include = nil

      if about
        case about
          when "nodes"
            data_type = :node
          when "components"
            data_type = :component
            detail_to_include = [:component_dependencies]
          when "attributes"
            data_type = :attribute
            detail_to_include = [:attribute_links]
          when "tasks"
            data_type = :task
          else
            raise_validation_error_method_usage('list')
        end 
      end

      post_body = {
        :assembly_id => assembly_id,
        :node_id => node_id,
        :component_id => component_id,
        :subtype     => 'instance'
      }
      post_body.merge!(:detail_to_include => detail_to_include) if detail_to_include
      rest_endpoint = "assembly/info_about"

      if context_params.is_last_command_eql_to?(:attribute)        
        raise DTK::Client::DtkError, "Not supported command for current context level." if attribute_id
        about, data_type = get_type_and_raise_error_if_invalid(about, "attributes", ["attributes"])
      elsif context_params.is_last_command_eql_to?(:component)
        if component_id
          about, data_type = get_type_and_raise_error_if_invalid(about, "attributes", ["attributes"])
        else
          about, data_type = get_type_and_raise_error_if_invalid(about, "components", ["attributes", "components"])
        end
      elsif context_params.is_last_command_eql_to?(:node)
        if node_id
          about, data_type = get_type_and_raise_error_if_invalid(about, "components", ["attributes", "components"])
        else
          about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes"])
        end
      else
        if assembly_id
          about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes", "tasks"])
        else
          data_type = :assembly
          post_body = { :subtype  => 'instance', :detail_level => 'nodes' }
          rest_endpoint = "assembly/list"
        end  
      end

      post_body[:about] = about
      response = post rest_url(rest_endpoint), post_body

      # set render view to be used
      response.render_table(data_type)

      return response
    end

    # desc "ASSEMBLY-NAME/ID list-attribute-mappings SERVICE-LINK-NAME/ID", "List attribute mappings associated with service link"
    # def list_attribute_mappings(context_params)
    #   post_body = Helper(:service_link).post_body_with_id_keys(context_params,method_argument_names)
    #   post rest_url("assembly/list_attribute_mappings"), post_body
    # end

    #desc "ASSEMBLY-NAME/ID list-smoketests","List smoketests on asssembly"
    #def list_smoketests(context_params)
    #  assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)
    #
    #  post_body = {
    #    :assembly_id => assembly_id
    #  }
    #  post rest_url("assembly/list_smoketests"), post_body
    #end

    desc "ASSEMBLY-NAME/ID info", "Get info about content of the assembly."
    def info(context_params)
      info_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID link-attributes TARGET-ATTR SOURCE-ATTR", "Link the value of the target attribute to the source attribute."
    def link_attributes(context_params)
      link_attributes_aux(context_params)
    end

    desc "delete-and-destroy ASSEMBLY-NODE/ID [-y]", "Delete assembly instance, terminating any nodes that have been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_and_destroy(context_params)
      assembly_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      assembly_name = get_assembly_name(assembly_id)

      unless options.force?
        # Ask user if really want to delete assembly, if not then return to dtk-shell without deleting
        #used form "+'?' because ?" confused emacs ruby rendering
        what = "assembly"
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy #{what} '#{assembly_name}' and its nodes"+'?')
      end

      #purge local clone
      response = purge_clone_aux(:all,:assembly_module => {:assembly_name => assembly_name})
      return response unless response.ok?

      post_body = {
        :assembly_id => assembly_id,
        :subtype => :instance
      }

      response = post rest_url("assembly/delete"), post_body
         
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly
      response
    end

    desc "ASSEMBLY-NAME/ID set-attribute ATTRIBUTE-NAME [VALUE] [-u]", "(Un)Set attribute value. The option -u will unset the attribute's value."
    method_option :unset, :aliases => '-u', :type => :boolean, :default => false
    def set_attribute(context_params)
      set_attribute_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID create-attribute ATTRIBUTE-NAME [VALUE] [--type DATATYPE] [--required] [--dynamic]", "Create a new attribute and optionally assign it a value."
    method_option :required, :type => :boolean, :default => false
    method_option :dynamic, :type => :boolean, :default => false
    method_option "type",:aliases => "-t"
    def create_attribute(context_params)
      create_attribute_aux(context_params)
    end

  #  desc "ASSEMBLY-NAME/ID add-assembly ASSEMBLY-TEMPLATE-NAME/ID", "Add (stage) an assembly template to become part of this assembly instance"
  #  method_option "auto-complete",:aliases => "-a" ,
  #    :type => :boolean, 
  #    :default=> false,
  #    :desc => "Automatically add in connections"
  #  def add_assembly(context_params)
  #    assembly_id,assembly_template_id = context_params.retrieve_arguments([:assembly_id,:option_1!],method_argument_names)
  #    post_body = {
  #      :assembly_id => assembly_id,
  #      :assembly_template_id => assembly_template_id
  #    }
  #    post_body.merge!(:auto_add_connections => true) if options.auto_complete?
  #    post rest_url("assembly/add_assembly_template"), post_body
  #  end

    # using ^^ before NODE-NAME to remove this command from assembly/assembly_id/node/node_id but show in assembly/assembly_id
    desc "ASSEMBLY-NAME/ID create-node ^^NODE-NAME NODE-TEMPLATE", "Add (stage) a new node in the assembly."
    def create_node(context_params)
      response = create_node_aux(context_params)
      @@invalidate_map << :assembly_node

      return response
    end

    desc "ASSEMBLY-NAME/ID link-components TARGET-CMP-NAME SOURCE-CMP-NAME [DEPENDENCY-NAME]","Link the target component to the source component."
    def link_components(context_params)
      link_components_aux(context_params)
    end

    # only supported at node-level
    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE create-component NODE-NAME COMPONENT", "Add a component to the assembly."
    def create_component(context_params)
      create_component_aux(context_params)
    end

    # using ^^ before NODE-NAME to remove this command from assembly/assembly_id/node/node_id but show in assembly/assembly_id
    desc "ASSEMBLY-NAME/ID delete-node ^^NODE-NAME [-y]","Delete node, terminating it if the node has been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_node(context_params)
      response = delete_node_aux(context_params)
      @@invalidate_map << :assembly_node

      return response
    end

    desc "HIDE_FROM_BASE delete NAME/ID [-y]","Delete node, terminating it if the node has been spun up."
    def delete(context_params)
      if context_params.is_last_command_eql_to?(:node)
        response = delete_node_aux(context_params)
        return response unless response.ok?
        @@invalidate_map << :assembly_node

        response
      elsif context_params.is_last_command_eql_to?(:component)
        response = delete_component_aux(context_params)
        return response unless response.ok?
        @@invalidate_map << :assembly_node_component

        response
      end
    end

    desc "ASSEMBLY-NAME/ID unlink-components TARGET-CMP-NAME SOURCE-CMP-NAME [DEPENDENCY-NAME]", "Remove a component link."
    def unlink_components(context_params)
      unlink_components_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE delete-component COMPONENT","Delete component from the assembly."
    #desc "delete-component COMPONENT-ID [-y]","Delete component from workspace"
    #method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_component(context_params)
      response = delete_component_aux(context_params)
      return response unless response.ok?
      @@invalidate_map << :assembly_node_component

      response
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE edit","Edit component module related to given component."
    def edit(context_params)
      assembly_id, component_id = context_params.retrieve_arguments([:assembly_id!, :component_id!], method_argument_names)

      post_body = {
        :assembly_id => assembly_id,
        :component_id => component_id
      }
      response = post(rest_url("assembly/get_components_module"), post_body)
      return response unless response.ok?

      component_module = response['data']['component']
      version             = response['data']['version']
      
      context_params_for_service = DTK::Shell::ContextParams.new
      context_params_for_service.add_context_to_params(component_module['display_name'], "module", component_module['id']) unless component_module.nil?
      context_params_for_service.override_method_argument!('option_1', version)
        
      response = DTK::Client::ContextRouter.routeTask("module", "edit", context_params_for_service, @conn)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE get-netstats", "Get netstats"
    def get_netstats(context_params)
      get_netstats_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE get-ps [--filter PATTERN]", "Get ps"
    method_option :filter, :type => :boolean, :default => false, :aliases => '-f'
    def get_ps(context_params)
      get_ps_aux(context_params)
    end

    desc "ASSEMBLY-NAME/ID set-required-params", "Interactive dialog to set required params that are not currently set"
    def set_required_params(context_params)
      assembly_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)
      set_required_params_aux(assembly_id,:assembly,:instance)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE tail NODES-IDENTIFIER LOG-PATH [REGEX-PATTERN] [--more]","Tail specified number of lines from log"
    method_option :more, :type => :boolean, :default => false
    def tail(context_params)
      tail_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE grep LOG-PATH NODES-ID-PATTERN GREP-PATTERN [--first]","Grep log from multiple nodes. --first option returns first match (latest log entry)."
    method_option :first, :type => :boolean, :default => false
    def grep(context_params)
      grep_aux(context_params)
    end

    
  end
end

