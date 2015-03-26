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
dtk_require_common_commands('thor/action_result_handler')

LOG_SLEEP_TIME   = DTK::Configuration.get(:tail_log_frequency)
DEBUG_SLEEP_TIME = DTK::Configuration.get(:debug_task_frequency)

module DTK::Client
  class Service < CommandBaseThor

    no_tasks do
      include TaskStatusMixin
      include SetRequiredParamsMixin
      include EditMixin
      include PurgeCloneMixin
      include AssemblyWorkspaceMixin
      include ActionResultHandler

      def get_assembly_name(assembly_id)
        get_name_from_id_helper(assembly_id)
      end

      def get_assembly_id(assembly_name)
        assembly_id = nil
        list = CommandBaseThor.get_cached_response(:service, "assembly/list", {})

        list.data.each do |item|
          if item["display_name"] == assembly_name
            assembly_id = item["id"]
            break
          end
        end

        raise DtkError,"[ERROR] Illegal name (#{assembly_name}) for service." unless assembly_id
        assembly_id
      end



    end

    def self.whoami()
      return :service, "assembly/list", {:subtype  => 'instance'}
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
          :add_component => "component_template",
          :create_node => "node_template",
          :create_node_group => "node_template",
          :add_component_dependency => "component_template"
        },
        :command => {
          :edit_component_module => {
            :endpoint => "assembly",
            :url => "assembly/info_about",
            :opts => {:subtype=>"instance", :about=>"modules"}
          },
          :push_component_module_updates => {
            :endpoint => "assembly",
            :url => "assembly/info_about",
            :opts => {:subtype=>"instance", :about=>"modules"}
          },
          :delete_node => {
            :endpoint => "assembly",
            :url => "assembly/get_nodes_without_node_groups"
          },
          :delete_node_group => {
            :endpoint => "assembly",
            :url => "assembly/get_node_groups"
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
      return Service.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      get_cached_response(:service, "assembly/list", {})
    end

    # TODO: Hack which is necessery for the specific problem (DTK-541), something to reconsider down the line
    # at this point not sure what would be clenear solution

    # :all             => include both for commands with command and identifier
    # :command_only    => only on command level
    # :identifier_only => only on identifier level for given entity (command)
    #
    def self.override_allowed_methods()
      override_methods = {
        :all => {
          # :node => [
            # ['delete-component',"delete-component COMPONENT-ID","# Delete component from assembly's node"],
            # ['list-components',"list-components","# List components associated with assembly's node."],
            # ['list-attributes',"list-attributes","# List attributes associated with assembly's node."]
          # ],
          :component => [
            ['list-attributes',"list-attributes","# List attributes associated with given component."]
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
            ['execute-tests',"execute-tests [--component COMPONENT-NAME] [--timeout TIMEOUT]","# Execute tests. --component filters execution per component, --timeout changes default execution timeout."],
            ['get-netstats',"get-netstats","# Get netstats."],
            ['get-ps',"get-ps [--filter PATTERN]","# Get ps."],
            ['grep',"grep LOG-PATH NODE-ID-PATTERN GREP-PATTERN [--first]","# Grep log from multiple nodes. --first option returns first match (latest log entry)."],
            ['tail',"tail NODE-NAME LOG-PATH [REGEX-PATTERN] [--more]","# Tail specified number of lines from log."]
          ]
        },
        :identifier_only => {
          :node      => [
            ['add-component',"add-component COMPONENT","# Add a component to the node."],
            ['delete-component',"delete-component COMPONENT-NAME [-y]","# Delete component from service's node"],
            ['info',"info","# Return info about node instance belonging to given workspace."],
            ['list-attributes',"list-attributes","# List attributes associated with service's node."],
            ['list-components',"list-components","# List components associated with service's node."],
            ['set-attribute',"set-attribute ATTRIBUTE-NAME [VALUE] [-u]","# (Un)Set attribute value. The option -u will unset the attribute's value."],
            ['start', "start", "# Start node instance."],
            ['stop', "stop", "# Stop node instance."],
            ['ssh', "ssh REMOTE-USER [-i PATH-TO-PEM]","# SSH into node, optional parameters are path to identity file."]
          ],
          :node_group => [
            ['start', "start", "# 2Start node instance."],
            ['stop', "stop", "# 2Stop node instance."],
            ['ssh', "ssh REMOTE-USER [-i PATH-TO-PEM]","# 2SSH into node, optional parameters are path to identity file."]
          ],
          :component => [
            ['info',"info","# Return info about component instance belonging to given node."],
            ['edit',"edit","# Edit component module related to given component."],
            ['link-components',"link-components ANTECEDENT-CMP-NAME [DEPENDENCY-NAME]","#Link components to satisfy component dependency relationship."],
            ['list-component-links',"list-component-links","# List component's links to other components."],
            ['unlink-components',"unlink-components SERVICE-TYPE","# Delete service link on component."]
          ],
          :attribute => [
            ['info',"info","# Return info about attribute instance belonging to given component."]
          ]
        }
      }

      if ::DTK::Configuration.get(:development_mode)
        override_methods[:identifier_only][:node] << ['test-action-agent', "test-action-agent BASH-COMMAND-LINE", "Run bash command on test action agent"]
      end

      return DTK::Shell::OverrideTasks.new(override_methods, [:utils])
    end

    desc "SERVICE-NAME/ID destroy-and-reset-nodes [-y]", "Terminates all nodes, but keeps config state so they can be spun up from scratch."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def destroy_and_reset_nodes(context_params)
      destroy_and_reset_nodes_aux(context_params)
    end


    desc "SERVICE-NAME/ID start [NODE-NAME]", "Starts all the service nodes. A single node can be selected."
    def start(context_params)
      start_aux(context_params)
    end

    desc "SERVICE-NAME/ID stop [NODE-NAME]", "Stops all the service nodes. A single node can be selected."
    def stop(context_params)
      stop_aux(context_params)
    end


    desc "SERVICE-NAME/ID cancel-task [TASK_ID]", "Cancels an executing task.  If task id is omitted, this command cancels the most recent executing task."
    def cancel_task(context_params)
      cancel_task_aux(context_params)
    end

    desc "SERVICE-NAME/ID create-assembly [NAMESPACE:]SERVICE-MODULE-NAME ASSEMBLY-NAME [-m DESCRIPTION]", "Create a new assembly from this service instance in the designated service module."
    method_option "description",:aliases => "-m" ,
      :type => :string,
      :banner => "DESCRIPTION"
    def create_assembly(context_params)
      assembly_id, service_module_name, assembly_template_name = context_params.retrieve_arguments([:service_id!,:option_1!,:option_2!],method_argument_names)

      # need default_namespace for create-assembly because need to check if local service-module directory existst in promote_assembly_aux
      resp = post rest_url("namespace/default_namespace_name")
      return resp unless resp.ok?
      default_namespace = resp.data

      opts = {:default_namespace => default_namespace}
      opts.merge!(:description => options.description) if options.description
      response = promote_assembly_aux(:create,assembly_id,service_module_name,assembly_template_name,opts)
      return response unless response.ok?

      @@invalidate_map << :assembly
      @@invalidate_map << :service

      Response::Ok.new()
    end

    # TODO: DTK-1986 introduces the hidden optional terms [WORKFLOW-ACTION [WORKFLOW-PARAMS]]
    # desc "SERVICE-NAME/ID converge [-m COMMIT-MSG] [WORKFLOW-ACTION [WORKFLOW-PARAMS]]", "Converge service instance."
    desc "SERVICE-NAME/ID converge [-m COMMIT-MSG]", "Converge service instance."
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string,
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def converge(context_params)
      converge_aux(context_params)
    end

    desc "SERVICE-NAME/ID push-assembly-updates [NAMESPACE:SERVICE-MODULE-NAME/ASSEMBLY-NAME]", "Push changes made to this service instance to the designated assembly; default is parent assembly."
    def push_assembly_updates(context_params)
      assembly_id, qualified_assembly_name = context_params.retrieve_arguments([:service_id!,:option_1],method_argument_names)
      service_module_name, assembly_template_name =
        if qualified_assembly_name
          if qualified_assembly_name =~ /(^[^\/]*)\/([^\/]*$)/
            [$1,$2]
          else
            raise DtkError,"The term (#{qualified_assembly_name}) must have form SERVICE-MODULE-NAME/ASSEMBLY-NAME"
          end
        else
          [nil,nil]
        end

      response = promote_assembly_aux(:update,assembly_id, service_module_name, assembly_template_name,{:use_module_namespace=>true})
      return response unless response.ok?
      @@invalidate_map << :assembly
      Response::Ok.new()
    end

    desc "SERVICE-NAME/ID push-component-module-updates COMPONENT-MODULE-NAME [--force]", "Push changes made to a component module in the service to its base component module."
    method_option :force, :type => :boolean, :default => false, :aliases => '-f'
    def push_component_module_updates(context_params)
      push_module_updates_aux(context_params)
    end

    desc "SERVICE-NAME/ID edit-component-module COMPONENT-MODULE-NAME", "Edit a component module used in the service."
    def edit_component_module(context_params)
      edit_module_aux(context_params)
    end

    desc "SERVICE-NAME/ID edit-workflow", "Edit service's workflow."
    def edit_workflow(context_params)
      edit_workflow_aux(context_params)
    end

    desc "SERVICE-NAME/ID edit-attributes", "Edit service's attributes."
    def edit_attributes(context_params)
      edit_attributes_aux(context_params)
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

    desc "SERVICE-NAME/ID task-status [--wait] [--summarize]", "Get the task status of the running or last running service task."
    method_option :wait, :type => :boolean, :default => false
    method_option :summarize, :type => :boolean, :default => false, :aliases => '-s'
    def task_status(context_params)
      task_status_aw_aux(context_params)
    end

    desc "SERVICE-NAME/ID task-action-detail", "Get the task info of the running or last running service task."
    def task_action_detail(context_params)
      task_action_detail_aw_aux(context_params)
    end

    desc "SERVICE-NAME/ID list-nodes","List nodes associated with service."
    def list_nodes(context_params)
      list_nodes_aux(context_params)
    end

    desc "SERVICE-NAME/ID list-component-links","List component links."
    def list_component_links(context_params)
      list_component_links_aux(context_params)
    end

    desc "SERVICE-NAME/ID list-components [--deps]","List components associated with service."
    method_option :deps, :type => :boolean, :default => false, :aliases => '-l'
    def list_components(context_params)
      list_components_aux(context_params)
    end

    desc "SERVICE-NAME/ID list-attributes [-f FORMAT] [-t TAG,..] [--links]","List attributes associated with service."
    method_option :format, :aliases => '-f'
    method_option :tags, :aliases => '-t'
    method_option :links, :type => :boolean, :default => false, :aliases => '-l'
    def list_attributes(context_params)
      list_attributes_aux(context_params)
    end

    desc "SERVICE-NAME/ID list-component-modules","List component modules associated with service."
    def list_component_modules(context_params)
      list_modules_aux(context_params)
    end

    desc "SERVICE-NAME/ID list-tasks","List tasks associated with service."
    def list_tasks(context_params)
      list_tasks_aux(context_params)
    end

    desc "SERVICE-NAME/ID list-violations", "Finds violations in the service that will prevent a converge operation."
    def list_violations(context_params)
      list_violations_aux(context_params)
    end

    desc "SERVICE-NAME/ID print-includes", "Finds includes in the service."
    def print_includes(context_params)
      print_includes_aux(context_params)
    end

    desc "SERVICE-NAME/ID workflow-info", "Get the structure of the workflow associated with service."
    def workflow_info(context_params)
      workflow_info_aux(context_params)
    end

    desc "list","List services."
    def list(context_params)
      assembly_id, node_id, component_id, attribute_id, about = context_params.retrieve_arguments([:service_id,:node_id,:component_id,:attribute_id,:option_1],method_argument_names)
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
          post_body = { :subtype  => 'instance', :detail_level => 'nodes',:include_namespaces => true}
          rest_endpoint = "assembly/list"
        end
      end

      post_body[:about] = about
      response = post rest_url(rest_endpoint), post_body

      # set render view to be used
      response.render_table(data_type)

      return response
    end

    desc "SERVICE-NAME/ID list-diffs COMPONENT-MODULE-NAME", "List diffs between module in service instance and base module."
    def list_diffs(context_params)
      list_remote_module_diffs(context_params)
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

    desc "SERVICE-NAME/ID grant-access USER-ACCOUNT PUB-KEY-NAME [PATH-TO-PUB-KEY] [--nodes NODE-NAMES]", "Grants ssh access to user account USER-ACCOUNT for nodes in service instance"
    method_option :nodes, :type => :string, :default => nil
    def grant_access(context_params)
      grant_access_aux(context_params)
    end

    desc "SERVICE-NAME/ID revoke-access USER-ACCOUNT PUB-KEY-NAME [PATH-TO-PUB-KEY] [--nodes NODE-NAMES]", "Revokes ssh access to user account USER-ACCOUNT for nodes in service instance"
    method_option :nodes, :type => :string, :default => nil
    def revoke_access(context_params)
      revoke_access_aux(context_params)
    end

    desc "SERVICE-NAME/ID list-ssh-access", "List SSH access for each of the nodes"
    def list_ssh_access(context_params)
      list_ssh_access_aux(context_params)
    end

    desc "SERVICE-NAME/ID info", "Get info about content of the service."
    def info(context_params)
      info_aux(context_params)
    end

    desc "SERVICE-NAME/ID link-attributes TARGET-ATTR SOURCE-ATTR", "Link the value of the target attribute to the source attribute."
    def link_attributes(context_params)
      link_attributes_aux(context_params)
    end

    desc "delete-and-destroy NAME/ID [-y]", "Delete service instance, terminating any nodes that have been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_and_destroy(context_params)
      assembly_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      if assembly_name.to_s =~ /^[0-9]+$/
        assembly_id = assembly_name
      else
        assembly_id = get_assembly_id(assembly_name)
      end

      unless options.force?
        # Ask user if really want to delete assembly, if not then return to dtk-shell without deleting
        # used form "+'?' because ?" confused emacs ruby rendering
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy service '#{assembly_name}' and its nodes"+'?')
      end

      unsaved_modules = check_if_unsaved_cmp_module_changes(assembly_id)
      unless unsaved_modules.empty?
        return unless Console.confirmation_prompt("Deleting this service will cause unsaved changes in component module(s) '#{unsaved_modules.join(',')}' to be lost. Do you still want to proceed"+'?')
      end

      assembly_changed = check_if_unsaved_assembly_changes(assembly_id, assembly_name)
      if assembly_changed == true
        return unless Console.confirmation_prompt("You made some changes in assembly or it's workflow that will be lost if you delete this service. Do you still want to proceed"+'?')
      end

      # purge local clone
      response = purge_clone_aux(:all,:assembly_module => {:assembly_name => assembly_name})
      return response unless response.ok?

      post_body = {
        :assembly_id => assembly_id,
        :subtype => :instance
      }

      response = post rest_url("assembly/delete"), post_body

      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :service
      @@invalidate_map << :assembly
      response
    end

    desc "SERVICE-NAME/ID set-attribute ATTRIBUTE-NAME [VALUE] [-u]", "(Un)Set attribute value. The option -u will unset the attribute's value."
    method_option :unset, :aliases => '-u', :type => :boolean, :default => false
    def set_attribute(context_params)
      set_attribute_aux(context_params)
    end

    desc "SERVICE-NAME/ID create-attribute ATTRIBUTE-NAME [VALUE] [--type DATATYPE] [--required] [--dynamic]", "Create a new attribute and optionally assign it a value."
    method_option :required, :type => :boolean, :default => false
    method_option :dynamic, :type => :boolean, :default => false
    method_option "type",:aliases => "-t"
    def create_attribute(context_params)
      create_attribute_aux(context_params)
    end

    # using ^^ before NODE-NAME to remove this command from assembly/assembly_id/node/node_id but show in assembly/assembly_id
    desc "SERVICE-NAME/ID create-node ^^NODE-NAME NODE-TEMPLATE", "Add (stage) a new node in the service."
    def create_node(context_params)
      response = create_node_aux(context_params)
      return response unless response.ok?

      @@invalidate_map << :assembly
      @@invalidate_map << :assembly_node
      @@invalidate_map << :service
      @@invalidate_map << :service_node
      @@invalidate_map << :workspace
      @@invalidate_map << :workspace_node

      message = "Created node '#{response.data["display_name"]}'."
      DTK::Client::OsUtil.print(message, :yellow)
    end

    desc "SERVICE-NAME/ID create-node-group ^^NODE-GROUP-NAME NODE-TEMPLATE [-n CARDINALITY]", "Add (stage) a new node group in the service."
    method_option :cardinality, :aliases => '-n', :type => :string, :default => 1
    def create_node_group(context_params)
      response = create_node_group_aux(context_params)
      return response unless response.ok?

      @@invalidate_map << :assembly
      @@invalidate_map << :assembly_node
      @@invalidate_map << :service
      @@invalidate_map << :service_node
      @@invalidate_map << :workspace
      @@invalidate_map << :workspace_node

      message = "Created node group '#{response.data["display_name"]}'."
      DTK::Client::OsUtil.print(message, :yellow)
    end

    desc "SERVICE-NAME/ID link-components TARGET-CMP-NAME SOURCE-CMP-NAME [DEPENDENCY-NAME]","Link the target component to the source component."
    def link_components(context_params)
      link_components_aux(context_params)
    end

    # only supported at node-level
    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE add-component NODE-NAME COMPONENT", "Add a component to the service."
    def add_component(context_params)
      response = create_component_aux(context_params)

      @@invalidate_map << :service
      @@invalidate_map << :service_node

      response
    end

    # using ^^ before NODE-NAME to remove this command from assembly/assembly_id/node/node_id but show in assembly/assembly_id
    desc "SERVICE-NAME/ID delete-node ^^NODE-NAME [-y]","Delete node, terminating it if the node has been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_node(context_params)
      response = delete_node_aux(context_params)

      @@invalidate_map << :assembly
      @@invalidate_map << :assembly_node
      @@invalidate_map << :service
      @@invalidate_map << :service_node
      @@invalidate_map << :workspace
      @@invalidate_map << :workspace_node

      return response
    end

    desc "SERVICE-NAME/ID delete-node-group ^^NODE-NAME [-y]","Delete node group and all nodes that are part of that group."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_node_group(context_params)
      response = delete_node_group_aux(context_params)

      @@invalidate_map << :assembly
      @@invalidate_map << :assembly_node
      @@invalidate_map << :service
      @@invalidate_map << :service_node
      @@invalidate_map << :workspace
      @@invalidate_map << :workspace_node

      return response
    end

    desc "HIDE_FROM_BASE delete NAME/ID [-y]","Delete node, terminating it if the node has been spun up."
    def delete(context_params)
      if context_params.is_last_command_eql_to?(:node)
        response = delete_node_aux(context_params)
        return response unless response.ok?
        @@invalidate_map << :service_node

        response
      elsif context_params.is_last_command_eql_to?(:component)
        response = delete_component_aux(context_params)
        return response unless response.ok?
        @@invalidate_map << :assembly_node_component

        response
      end
    end

    desc "SERVICE-NAME/ID unlink-components TARGET-CMP-NAME SOURCE-CMP-NAME [DEPENDENCY-NAME]", "Remove a component link."
    def unlink_components(context_params)
      unlink_components_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE delete-component COMPONENT-NAME [-y]","Delete component from the service."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_component(context_params)
      response = delete_component_aux(context_params)

      @@invalidate_map << :service
      @@invalidate_map << :service_node
      @@invalidate_map << :service_node_component

      response
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE get-netstats", "Get netstats"
    def get_netstats(context_params)
      get_netstats_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE execute-tests [--component COMPONENT-NAME] [--timeout TIMEOUT]", "Execute tests. --component filters execution per component, --timeout changes default execution timeout"
    method_option :component, :type => :string, :desc => "Component name"
    method_option :timeout, :type => :string, :desc => "Timeout"
    def execute_tests(context_params)
      execute_tests_aux(context_params)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE get-ps [--filter PATTERN]", "Get ps"
    method_option :filter, :type => :boolean, :default => false, :aliases => '-f'
    def get_ps(context_params)
      get_ps_aux(context_params)
    end

    desc "SERVICE-NAME/ID set-required-params", "Interactive dialog to set required params that are not currently set"
    def set_required_params(context_params)
      assembly_id = context_params.retrieve_arguments([:service_id!],method_argument_names)
      set_required_params_aux(assembly_id,:assembly,:instance)
    end

    # using HIDE_FROM_BASE to hide this command from base context (dtk:/assembly>)
    desc "HIDE_FROM_BASE tail NODE-NAME LOG-PATH [REGEX-PATTERN] [--more]","Tail specified number of lines from log"
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

