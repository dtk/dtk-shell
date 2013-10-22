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
LOG_SLEEP_TIME_W   = DTK::Configuration.get(:tail_log_frequency)

# regex: (context_params.retrieve_arguments\([a-z\[\]:_,0-9!]+)
# replace: $1,method_argument_names

module DTK::Client
  class Workspace < CommandBaseThor
    no_tasks do
      include TaskStatusMixin
      include SetRequiredParamsMixin
      include EditMixin
      include PurgeCloneMixin
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
      [:node]
    end

    # using extended_context when we want to use autocomplete from other context
    # e.g. we are in assembly/apache context and want to add-component we will use extended context to add 
    # component-templates to autocomplete
    def self.extended_context()
      {:add_component => "component_template", :create_node => "node_template"}
    end

    # this includes children of children
    def self.all_children()
      [:node, :component, :attribute]
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
            ['delete-component',"delete-component COMPONENT-ID","# Delete component from assembly's node"],
            # ['list',"list [FILTER] [--list] ","# List nodes"],
            ['list-components',"list-components","# List components associated with workspace's node."],
            ['list-attributes',"list-attributes","# List attributes associated with workspace's node."]
          ],
          :component => [
            # ['list',"list [FILTER] [--list] ","# List components."],
            ['list-attributes',"list-attributes","# List attributes associated with given component."]
            # ['list-service-links',"list-service-links","# List service links for component."],
            # ['create-service-link',"create-service-link SERVICE-TYPE DEPENDENT-CMP-NAME/ID","# Add service link to component."],
            # ['delete-service-link',"delete-service-link SERVICE-TYPE","# Delete service link on component."],
            # ['create-attribute',"create-attribute SERVICE-TYPE DEP-ATTR ARROW BASE-ATTR","# Create an attribute to service link."],
            # ['list-attribute-mappings',"list-attribute-mappings SERVICE-TYPE","# List attribute mappings assocaited with service link."]
          ]
        },
        :command_only => {
          :attribute => [
            ['list',"list [attributes]","# List attributess."]
          ],
          :node => [
            ['delete',"delete NAME/ID [-y] ","# Delete node, terminating it if the node has been spun up."],
            ['list-nodes',"list-nodes ","# List nodes."]
          ],
          :component => [
            ['delete',"delete NAME/ID [-y] ","# Delete node, terminating it if the node has been spun up."]
          ]
        },
        :identifier_only => {
          :node      => [
            ['add-component',"add-component COMPONENT-TEMPLATE-NAME/ID [DEPENDENCY-ORDER-INDEX]","# Add component to node. Default workflow order position is at the end."],
            # ['delete-component',"delete-component COMPONENT-ID","# Delete component from assembly node."],
            ['info',"info","# Return info about node instance belonging to given workspace."],
            ['get-netstats',"get-netstats","# Returns getnetstats for given node instance belonging to context workspace."],
            ['get-ps', "get-ps [--filter PATTERN]", "# Returns a list of running processes for a given node instance belonging to context workspace."],
            ['link-attribute-to', "link-attribute-to TARGET-ATTR-TERM SOURCE-ATTR-TERM", "# Set TARGET-ATTR-TERM to SOURCE-ATTR-TERM."]
          ],
          :component => [
            ['info',"info","# Return info about component instance belonging to given node."],
            ['list-service-links',"list-service-links","# List service links for component."],
            ['create-service-link',"create-service-link SERVICE-TYPE DEPENDENT-CMP-NAME/ID","# Add service link to component."],
            ['delete-service-link',"delete-service-link SERVICE-TYPE","# Delete service link on component."],
            ['create-attribute',"create-attribute SERVICE-TYPE DEP-ATTR ARROW BASE-ATTR","# Create an attribute to service link."],
            ['list-attribute-mappings',"list-attribute-mappings SERVICE-TYPE","# List attribute mappings assocaited with service link."],
            ['edit',"edit","# Edit component module related to given component."]
          ],
          :attribute => [
            ['info',"info","# Return info about attribute instance belonging to given component."]
          ]
        }
      })
    end

    desc "WORKSPACE-NAME/ID start [NODE-ID-PATTERN]", "Starts all workspace's nodes,  specific nodes can be selected via node id regex."
    def start(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [:workspace_id!,:node_id]
      else
        mapping = [:workspace_id!,:option_1]
      end

      workspace_id, node_pattern = context_params.retrieve_arguments(mapping,method_argument_names)

      assembly_start(workspace_id, node_pattern)
    end

    desc "WORKSPACE-NAME/ID stop [NODE-ID-PATTERN]", "Stops all workspace's nodes, specific nodes can be selected via node id regex."
    def stop(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [:workspace_id!,:node_id]
      else
        mapping = [:workspace_id!,:option_1]
      end

      workspace_id, node_pattern = context_params.retrieve_arguments(mapping,method_argument_names)

      assembly_stop(workspace_id, node_pattern)
    end

    desc "WORKSPACE-NAME/ID cancel-task TASK_ID", "Cancels task."
    def cancel_task(context_params)
      task_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      cancel_task_aux(task_id)
    end

    desc "WORKSPACE-NAME/ID create-assembly SERVICE-MODULE-NAME ASSEMBLY-TEMPLATE-NAME [-p]", "Creates a new assembly template or updates existing one from workspace instance. -p will purge workspace" 
    method_option :purge, :aliases => '-p', :type => :boolean, :default => false
    def create_assembly(context_params)
      workspace_id, service_module_name, assembly_template_name = context_params.retrieve_arguments([:workspace_id!,:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => workspace_id,
        :service_module_name => service_module_name,
        :assembly_template_name => assembly_template_name
      }
      response = post rest_url("assembly/promote_to_template"), post_body
      # when changing context send request for getting latest assembly_templates instead of getting from cache
      @@invalidate_map << :assembly_template

      return response unless response.ok?()
      #synchronize_clone will load new assembly template into service clone on workspace (if it exists)
      commit_sha,workspace_branch = response.data(:module_name,:workspace_branch)
      Helper(:git_repo).synchronize_clone(:service_module,service_module_name,commit_sha,:local_branch=>workspace_branch)

      if options.purge?
        purge(context_params)
      end
    end
    
    desc "WORKSPACE-NAME/ID list-violations", "Finds violations in workspace that will prevent a converge operation"
    def list_violations(context_params)
      workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)
      response = post rest_url("assembly/find_violations"),:assembly_id => workspace_id
      response.render_table(:violation)
    end
    
    desc "WORKSPACE-NAME/ID converge [-m COMMIT-MSG]", "Converges workspace instance. Optionally, puppet version can be forwarded."
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message" 
    def converge(context_params)
      workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)

      post_body = {
        :assembly_id => workspace_id
      }

      response = post rest_url("assembly/find_violations"), post_body
      return response unless response.ok?
      if response.data and response.data.size > 0
        #TODO: may not directly print here; isntead use a lower level fn
        error_message = "The following violations were found; they must be corrected before workspace can be converged"
        DTK::Client::OsUtil.print(error_message, :red)
        return response.render_table(:violation)
      end

      post_body.merge!(:commit_msg => options.commit_msg) if options.commit_msg

      response = post rest_url("assembly/create_task"), post_body
      return response unless response.ok?

      if response.data
        confirmation_message = response.data["confirmation_message"]
        
        if confirmation_message
          return unless Console.confirmation_prompt("Workspace assembly is stopped, do you want to start it"+'?')
          post_body.merge!(:start_assembly=>true)
          response = post rest_url("assembly/create_task"), post_body
          return response unless response.ok?
        end
      end

      # execute task
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "WORKSPACE-NAME/ID edit-module COMPONENT-MODULE-NAME", "Edit component module used by the workspace"
    def edit_module(context_params)
      workspace_id, component_module_name = context_params.retrieve_arguments([:workspace_id!,:option_1!],method_argument_names)
      post_body = {
        :assembly_id => workspace_id,
        :module_name => component_module_name,
        :module_type => 'component_module'
      }
      response = post rest_url("assembly/prepare_for_edit_module"), post_body
      return response unless response.ok?
      assembly_name,component_module_id,version,repo_url,branch = response.data(:assembly_name,:module_id,:version,:repo_url,:workspace_branch)
      edit_opts = {
        :automatically_clone => true,
        :assembly_module => {
          :assembly_name => assembly_name,
          :version => version
        },
        :workspace_branch_info => {
          :repo_url => repo_url,
          :branch => branch,
          :module_name => component_module_name
        }
      }
      version = nil #TODO: version associated with assembly is passed in edit_opts, which is a little confusing
      edit_aux(:component_module,component_module_id,component_module_name,version,edit_opts)
    end

    # desc "WORKSPACE-NAME/ID promote-module-updates COMPONENT-MODULE-NAME", "Promotes changes made to component module in assembly to shared template"
    # def promote_module_updates(context_params)
    #   workspace_id, component_module_name = context_params.retrieve_arguments([:workspace_id!,:option_1!],method_argument_names)
    #   post_body = {
    #     :assembly_id => workspace_id,
    #     :module_name => component_module_name,
    #     :module_type => 'component_module'
    #   }
    #   response = post(rest_url("assembly/promote_module_updates"),post_body)
    #   return response unless response.ok?
    #   return Response::Ok.new() unless response.data(:any_updates)
    #   if dsl_parsing_errors = response.data(:dsl_parsing_errors)
    #     error_message = "Module '#{component_module_name}' imported with errors:\n#{dsl_parsing_errors}\nYou can fix errors and import module again.\n"
    #     OsUtil.print(dsl_parsed_message, :red) 
    #     return Response::Error.new()
    #   end
    #   module_name,branch = response.data(:module_name,:workspace_branch)
    #   response = Helper(:git_repo).pull_changes?(:component_module,module_name,:local_branch => branch)
    #   return response unless response.ok?()
    #   Response::Ok.new()
    # end

    desc "WORKSPACE-NAME/ID list-task-info", "Task status details of running or last workspace task"
    def list_task_info(context_params)
      workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)
      #TODO: deprecate this method: list_task_info_aux("assembly", workspace_id)
      post_body = {
        :assembly_id => workspace_id,
        :subtype     => 'instance'
      }
      response = post(rest_url("assembly/info_about_task"),post_body)
      response
    end

    desc "WORKSPACE-NAME/ID task-status [--wait]", "Task status of running or last workspace task"
    method_option :wait, :type => :boolean, :default => false
    def task_status(context_params)
      workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)
      response = task_status_aux(workspace_id,:assembly,options.wait?)

      # TODO: Hack which is necessery for the specific problem (DTK-725), we don't get proper error message when there is a timeout doing converge
      unless response == true
        return response.merge("data" => [{ "errors" => {"message" => "Task does not exist for workspace."}}]) unless response["data"]
        response["data"].each do |data|
          if data["errors"]
            data["errors"]["message"] = "[TIMEOUT ERROR] Server is taking too long to respond." if data["errors"]["message"] == "error"
          end
        end
      end
     
      response
    end

    desc "WORKSPACE-NAME/ID list-nodes","List nodes associated with workspace."
    def list_nodes(context_params)
      context_params.method_arguments = ["nodes"]
      list_aux(context_params)
      # list_assemblies(context_params)
    end

    desc "WORKSPACE-NAME/ID list-components","List components associated with workspace."
    def list_components(context_params)
      context_params.method_arguments = ["components"]
      list_aux(context_params)
      # list_assemblies(context_params)
    end

    desc "WORKSPACE-NAME/ID list-attributes","List attributes associated with workspace."
    def list_attributes(context_params)
      context_params.method_arguments = ["attributes"]
      list_aux(context_params)
      # list_assemblies(context_params)
    end

    desc "WORKSPACE-NAME/ID list-tasks","List tasks associated with workspace."
    def list_tasks(context_params)
      context_params.method_arguments = ["tasks"]
      list_aux(context_params)
      # list_assemblies(context_params)
    end

    desc "WORKSPACE-NAME/ID list-assemblies","List assemblies for current workspace."
    def list_assemblies(context_params)
      data_type = :assembly
      post_body = { :subtype  => 'instance', :detail_level => 'nodes' }
      rest_endpoint = "assembly/list"
      response = post rest_url(rest_endpoint), post_body

      response.render_table(data_type)
      return response
    end

    # desc "WORKSPACE-NAME/ID list-assemblies","List assemblies for current workspace."
    # def list_assemblies(context_params)
    #   workspace_id, node_id, component_id, attribute_id, about = context_params.retrieve_arguments([:workspace_id,:node_id,:component_id,:attribute_id,:option_1],method_argument_names)
    #   detail_to_include = nil

    #   if about
    #     case about
    #       when "nodes"
    #         data_type = :node
    #       when "components"
    #         data_type = :component
    #         detail_to_include = [:component_dependencies]
    #       when "attributes"
    #         data_type = :attribute
    #         detail_to_include = [:attribute_links]
    #       when "tasks"
    #         data_type = :task
    #       else
    #         raise_validation_error_method_usage('list')
    #     end 
    #   end

    #   post_body = {
    #     :assembly_id => workspace_id,
    #     :node_id => node_id,
    #     :component_id => component_id,
    #     :subtype     => 'instance'
    #   }
    #   post_body.merge!(:detail_to_include => detail_to_include) if detail_to_include
    #   rest_endpoint = "assembly/info_about"

    #   if context_params.is_last_command_eql_to?(:attribute)        
    #     raise DTK::Client::DtkError, "Not supported command for current context level." if attribute_id
    #     about, data_type = get_type_and_raise_error_if_invalid(about, "attributes", ["attributes"])
    #   elsif context_params.is_last_command_eql_to?(:component)
    #     if component_id
    #       about, data_type = get_type_and_raise_error_if_invalid(about, "attributes", ["attributes"])
    #     else
    #       about, data_type = get_type_and_raise_error_if_invalid(about, "components", ["attributes", "components"])
    #     end
    #   elsif context_params.is_last_command_eql_to?(:node)
    #     if node_id
    #       about, data_type = get_type_and_raise_error_if_invalid(about, "components", ["attributes", "components"])
    #       data_type = :workspace_attribute
    #     else
    #       about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes"])
    #     end
    #   else
    #     if workspace_id
    #       about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes", "tasks"])
    #     else
    #       data_type = :assembly
    #       post_body = { :subtype  => 'instance', :detail_level => 'nodes' }
    #       rest_endpoint = "assembly/list"
    #     end  
    #   end

    #   post_body[:about] = about
    #   response = post rest_url(rest_endpoint), post_body

    #   if (data_type.to_s.eql?("workspace_attribute") && response["data"])
    #     response["data"].each do |data|
    #       unless(data["linked_to_display_form"].to_s.empty?)
    #         data_type = :workspace_attribute_w_link
    #         break
    #       end
    #     end
    #   end

    #   # set render view to be used
    #   response.render_table(data_type)

    #   return response
    # end

    desc "WORKSPACE-NAME/ID link-attribute-to TARGET-ATTR-TERM SOURCE-ATTR-TERM", "Set TARGET-ATTR-TERM to SOURCE-ATTR-TERM"
    def link_attribute_to(context_params)
      workspace_id, target_attr_term, source_attr_term = context_params.retrieve_arguments([:workspace_id!,:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => workspace_id,
        :target_attribute_term => target_attr_term,
        :source_attribute_term => source_attr_term
      }
      post rest_url("assembly/add_ad_hoc_attribute_links"), post_body
    end

    desc "WORKSPACE-NAME/ID list-attribute-mappings SERVICE-LINK-NAME/ID", "List attribute mappings associated with service link"
    def list_attribute_mappings(context_params)
      post_body = Helper(:service_link).post_body_with_id_keys(context_params,method_argument_names)
      post rest_url("assembly/list_attribute_mappings"), post_body
    end

    desc "WORKSPACE-NAME/ID create-attribute SERVICE-LINK-NAME/ID DEP-ATTR ARROW BASE-ATTR", "Add an attribute mapping to a service link"
    def create_attribute(context_params)
      post_body = Helper(:service_link).post_body_with_id_keys(context_params,method_argument_names)
      base_attr,arrow,dep_attr = context_params.retrieve_arguments([:option_2!,:option_3!,:option_4!],method_argument_names)
      post_body.merge!(:attribute_mapping => "#{base_attr} #{arrow} #{dep_attr}") #TODO: probably change to be hash
      post rest_url("assembly/add_ad_hoc_attribute_mapping"), post_body
    end

    desc "WORKSPACE-NAME/ID delete-service-link SERVICE-LINK-ID", "Delete a service link"
    def delete_service_link(context_params)
      post_body = Helper(:service_link).post_body_with_id_keys(context_params,method_argument_names)
      post rest_url("assembly/delete_service_link"), post_body
    end

    desc "WORKSPACE-NAME/ID create-service-link SERVICE-TYPE BASE-CMP-NAME/ID DEPENDENT-CMP-NAME/ID", "Add a service link between two components"
    def create_service_link(context_params)
      if context_params.is_last_command_eql_to?(:component)
        workspace_id,service_type,base_cmp,dep_cmp = context_params.retrieve_arguments([:workspace_id!,:option_1!,:component_id!,:option_2!],method_argument_names)
      else
        workspace_id,service_type,base_cmp,dep_cmp = context_params.retrieve_arguments([:workspace_id!,:option_1!,:option_2!,:option_3!],method_argument_names)
      end

      post_body = {
        :assembly_id => workspace_id,
        :service_type => service_type,
        :input_component_id => base_cmp, 
        :output_component_id => dep_cmp
      }
      post rest_url("assembly/add_service_link"), post_body
    end

    desc "WORKSPACE-NAME/ID list-service-links","List service links"
    def list_service_links(context_params)
      workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)
      post_body = {
        :assembly_id => workspace_id
      }
      data_type = :service_link
      if context_params.is_last_command_eql_to?(:component)
        component_id = context_params.retrieve_arguments([:component_id!],method_argument_names)
        post_body.merge!(:component_id => component_id, :context => "component")
        data_type = :service_link_from_component
      end
      response = post rest_url("assembly/list_service_links"), post_body
      response.render_table(data_type)
    end

    desc "WORKSPACE-NAME/ID list-connections","List connections between services on workspace"
    def list_connections(context_params)
      workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)

      post_body = {
        :assembly_id => workspace_id,
        :find_possible => true
      }
      response = post rest_url("assembly/list_connections"), post_body
      response.render_table(:possible_service_connection)
    end

    # desc "WORKSPACE-NAME/ID list-smoketests","List smoketests on asssembly"
    # def list_smoketests(context_params)
    #   workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)

    #   post_body = {
    #     :assembly_id => workspace_id
    #   }
    #   post rest_url("assembly/list_smoketests"), post_body
    # end

    desc "WORKSPACE-NAME/ID info", "Return info about workspace instance identified by name/id"
    def info(context_params)
      workspace_id, node_id, component_id, attribute_id = context_params.retrieve_arguments([:workspace_id!, :node_id, :component_id, :attribute_id],method_argument_names)
 
      post_body = {
        :assembly_id => workspace_id,
        :node_id     => node_id,
        :component_id => component_id,
        :attribute_id => attribute_id,
        :subtype     => :instance
      }

      resp = post rest_url("assembly/info"), post_body
      if (component_id.nil? && !node_id.nil?)
        resp.render_workspace_node_info("node")
      elsif (component_id && node_id)
        resp.render_workspace_node_info("component") 
      else
        return resp
      end
    end

    desc "WORKSPACE-NAME/ID delete-and-destroy [-y]", "Delete workspace instance, terminating any nodes that have been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_and_destroy(context_params)
      workspace_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      assembly_name = get_workspace_name(workspace_id)

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
        :assembly_id => workspace_id,
        :subtype => :instance
      }

      response = post rest_url("assembly/delete"), post_body
         
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly
      response
    end

    desc "WORKSPACE-NAME/ID set-attribute ATTRIBUTE-NAME/ID VALUE [-u] [-r]", "Set workspace attribute value(s). -u will unset attribute. -r will set only required attributes"
    method_option :unset, :aliases => '-u', :type => :boolean, :default => false
    method_option :required, :aliases => '-r', :type => :boolean, :default => false
    def  set_attribute(context_params)
      if options.required?
        workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)
        return set_required_params_aux(workspace_id,:assembly,:instance)
      end

      if context_params.is_there_identifier?(:attribute)
        mapping = (options.unset? ? [:workspace_id!,:attribute_id!] : [:workspace_id!,:attribute_id!,:option_1!])
      else
        mapping = (options.unset? ? [:workspace_id!,:option_1!] : [:workspace_id!,:option_1!,:option_2!])
      end
      
      workspace_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)
      post_body = {
        :assembly_id => workspace_id,
        :pattern => pattern,
        :value => value
      }
      #TODO: have this return format like assembly show attributes with subset of rows that gt changed
      post rest_url("assembly/set_attributes"), post_body
    end

    desc "WORKSPACE-NAME/ID create-attribute ATTRIBUTE-NAME [VALUE]", "Create attribute and optionally assign it a value"
    def create_attribute(context_params)
      if context_params.is_there_identifier?(:attribute)
        mapping = [:workspace_id!,:attribute_id!, :option_1]
      else
        mapping = [:workspace_id!,:option_1!,:option_2]
      end
      workspace_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)
      post_body = {
        :assembly_id => workspace_id,
        :pattern => pattern,
        :create => true,
      }
      post_body.merge!(:value => value) if value

      #TODO: have this return format like assembly show attributes with subset of rows that gt changed
      post rest_url("assembly/set_attributes"), post_body
    end

    # desc "WORKSPACE-NAME/ID unset ATTRIBUTE-NAME/ID", "Unset assembly attribute values(s)"
    # def unset(context_params)
    #   if context_params.is_there_identifier?(:attribute)
    #     mapping = [:workspace_id!,:attribute_id!]
    #   else
    #     mapping = [:workspace_id!,:option_1!]
    #   end
    #   workspace_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)
    #   post_body = {
    #     :assembly_id => workspace_id,
    #     :pattern => pattern,
    #     :value => nil
    #   }
    #   #TODO: have this return format like assembly show attributes with subset of rows that gt changed
    #   post rest_url("assembly/set_attributes"), post_body
    # end

    desc "WORKSPACE-NAME/ID add-assembly ASSEMBLY-TEMPLATE-NAME/ID", "Add (stage) an assembly template to become part of this workspace instance"
    method_option "auto-complete",:aliases => "-a" ,
      :type => :boolean, 
      :default=> false,
      :desc => "Automatically add in connections"
    def add_assembly(context_params)
      workspace_id,assembly_template_id = context_params.retrieve_arguments([:workspace_id,:option_1!],method_argument_names)
      post_body = {
        :assembly_id => workspace_id,
        :assembly_template_id => assembly_template_id
      }
      post_body.merge!(:auto_add_connections => true) if options.auto_complete?
      post rest_url("assembly/add_assembly_template"), post_body
    end

    desc "WORKSPACE-NAME/ID create-node ASSEMBLY-NODES-NAME NODE-TEMPLATE", "Add (stage) a new node to workspace"
    def create_node(context_params)
      workspace_id,assembly_node_name,node_template_identifier = context_params.retrieve_arguments([:workspace_id,:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => workspace_id,
        :assembly_node_name => assembly_node_name
      }
      post_body.merge!(:node_template_identifier => node_template_identifier) if node_template_identifier

      post rest_url("assembly/add_node"), post_body
    end

    desc "WORKSPACE-NAME/ID purge [-y]", "Purge the workspace, deleting and terminating any nodes that have been spun up."
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def purge(context_params)
      workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)
      unless options.force?
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy all nodes in the workspace"+'?')
      end

      post_body = {
        :assembly_id => workspace_id
      }
      response = post(rest_url("assembly/purge"),post_body)
    end

    desc "add-component COMPONENT-TEMPLATE-NAME/ID [DEPENDENCY-ORDER-INDEX]", "Add component to node. Default workflow order position is at the end."
    def add_component(context_params)
    
      # If method is invoked from 'assembly/node' level retrieve node_id argument 
      # directly from active context
      if context_params.is_there_identifier?(:node)
        mapping = [:workspace_id!,:node_id!,:option_1!,:option_2]
      else
        # otherwise retrieve node_id from command options
        mapping = [:workspace_id!,:option_1!,:option_2!,:option_3]
      end

      workspace_id,node_id,component_template_id,order_index = context_params.retrieve_arguments(mapping,method_argument_names)

      post_body = {
        :assembly_id => workspace_id,
        :node_id => node_id,
        :component_template_id => component_template_id,
        :order_index => order_index
      }

      response = post(rest_url("assembly/add_component"), post_body)
      return response unless response.ok?

      puts "Successfully added component to node."
    end

    desc "delete NAME/ID [-y]","Delete node, terminating it if the node has been spun up"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete(context_params)
    delete_node(context_params) if context_params.is_last_command_eql_to?(:node)   
    delete_component(context_params) if context_params.is_last_command_eql_to?(:component)
    end

    desc "WORKSPACE-NAME/ID delete-node NAME/ID [-y]","Delete node, terminating it if the node has been spun up"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_node(context_params)
      workspace_id, node_id = context_params.retrieve_arguments([:workspace_id!,:option_1!],method_argument_names)
      unless options.force?
        what = "node"
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy #{what} '#{node_id}'"+'?')
      end

      post_body = {
        :assembly_id => workspace_id,
        :node_id => node_id
      }
      response = post(rest_url("assembly/delete_node"),post_body)
    end

    desc "delete-component COMPONENT-ID","Delete component from assembly"
    def delete_component(context_params)
      workspace_id, node_id, component_id = context_params.retrieve_arguments([:workspace_id!,:node_id,:option_1!],method_argument_names)

      post_body = {
        :assembly_id => workspace_id,
        :node_id => node_id,
        :component_id => component_id
      }
      response = post(rest_url("assembly/delete_component"),post_body)
    end

    desc "COMPONENT-NAME/ID edit","Edit component module related to given component."
    def edit(context_params)
      workspace_id, component_id = context_params.retrieve_arguments([:workspace_id!, :component_id!], method_argument_names)

      post_body = {
        :assembly_id => workspace_id,
        :component_id => component_id
      }
      response = post(rest_url("assembly/get_components_module"), post_body)
      return response unless response.ok?

      component_module = response['data']['component']
      version             = response['data']['version']
      
      context_params_for_service = DTK::Shell::ContextParams.new
      context_params_for_service.add_context_to_params("module", "module", component_module['id']) unless component_module.nil?
      context_params_for_service.override_method_argument!('option_1', version)
        
      response = DTK::Client::ContextRouter.routeTask("module", "edit", context_params_for_service, @conn)
    end

    desc "WORKSPACE-NAME/ID get-netstats", "Get netstats"
    def get_netstats(context_params)
      netstat_tries = 6
      netstat_sleep = 0.5

      workspace_id,node_id = context_params.retrieve_arguments([:workspace_id!,:node_id],method_argument_names)

      post_body = {
        :assembly_id => workspace_id,
        :node_id => node_id
      }  

      response = post(rest_url("assembly/initiate_get_netstats"),post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => false,
          :sort_key => "port"
        }
        response = post(rest_url("assembly/get_action_results"),post_body)
        count += 1
        if count > netstat_tries or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == netstat_tries
            ret_only_if_complete = false
          end
          sleep netstat_sleep
        end
      end

      #TODO: needed better way to render what is one of teh feileds which is any array (:results in this case)
      response.set_data(*response.data(:results))
      response.render_table(:netstat_data)
    end

    desc "WORKSPACE-NAME/ID get-ps [--filter PATTERN]", "Get ps"
    method_option :filter, :type => :boolean, :default => false, :aliases => '-f'
    def get_ps(context_params)

      get_ps_tries = 6
      get_ps_sleep = 0.5

      workspace_id,node_id,filter_pattern = context_params.retrieve_arguments([:workspace_id!,:node_id, :option_1],method_argument_names)

      post_body = {
        :assembly_id => workspace_id,
        :node_id => node_id
      }  
      
      response = post(rest_url("assembly/initiate_get_ps"),post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => false,
          :sort_key => "pid"
        }
        response = post(rest_url("assembly/get_action_results"),post_body)
        count += 1
        if count > get_ps_tries or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == get_ps_tries
            ret_only_if_complete = false
          end
          sleep get_ps_sleep
        end
      end
      filtered = response.data(:results).flatten

      # Amar: had to add more complex filtering in order to print node id and node name in output, 
      #       as these two values are sent only in the first element of node's processes list
      unless (filter_pattern.nil? || !options["filter"])    
        node_id = ""
        node_name = ""    
        filtered.reject! do |r|
          match = r.to_s.include?(filter_pattern)
          if r["node_id"] && r["node_id"] != node_id
            node_id = r["node_id"]
            node_name = r["node_name"]
          end
             
          if match && !node_id.empty?
            r["node_id"] = node_id
            r["node_name"] = node_name
            node_id = ""
            node_name = ""
          end
          !match
        end 
      end

      response.set_data(*filtered)
      response.render_table(:ps_data)
    end


    # desc "WORKSPACE-NAME/ID set-required-params", "Interactive dialog to set required params that are not currently set"
    # def set_required_params(context_params)
    #   workspace_id = context_params.retrieve_arguments([:workspace_id!],method_argument_names)
    #   set_required_params_aux(workspace_id,:assembly,:instance)
    # end

    desc "WORKSPACE-NAME/ID tail NODE-ID LOG-PATH [REGEX-PATTERN] [--more]","Tail specified number of lines from log"
    method_option :more, :type => :boolean, :default => false
    def tail(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [:workspace_id!,:node_id!,:option_1!,:option_2]
      else
        mapping = [:workspace_id!,:option_1!,:option_2!,:option_3]
      end
      
      workspace_id,node_identifier,log_path,grep_option = context_params.retrieve_arguments(mapping,method_argument_names)
     
      last_line = nil
      begin

        file_path = File.join('/tmp',"dtk_tail_#{Time.now.to_i}.tmp")
        tail_temp_file = File.open(file_path,"a")

        file_ready = false

        t1 = Thread.new do
          while true
            post_body = {
              :assembly_id     => workspace_id,
              :subtype         => 'instance',
              :start_line      => last_line,
              :node_identifier => node_identifier,
              :log_path        => log_path,
              :grep_option     => grep_option
            }

            response = post rest_url("assembly/initiate_get_log"), post_body

            unless response.ok?
              raise DTK::Client::DtkError, "Error while getting log from server, there was no successful response."
            end

            action_results_id = response.data(:action_results_id)
            action_body = {
              :action_results_id => action_results_id,
              :return_only_if_complete => true,
              :disable_post_processing => true
            }

            # number of re-tries
            3.times do
              response = post(rest_url("assembly/get_action_results"),action_body)

              # server has found an error
              unless response.data(:results).nil?
                if response.data(:results)['error']
                  raise DTK::Client::DtkError, response.data(:results)['error']
                end
              end

              break if response.data(:is_complete)

              sleep(1)
            end

            raise DTK::Client::DtkError, "Error while logging there was no successful response after 3 tries." unless response.data(:is_complete)

            # due to complicated response we change its formating
            response = response.data(:results).first[1]

            unless response["error"].nil?
              raise DTK::Client::DtkError, response["error"]
            end

            # removing invalid chars from log
            output = response["output"].gsub(/`/,'\'')

            unless output.empty?
              file_ready = true
              tail_temp_file << output 
              tail_temp_file.flush
            end

            last_line = response["last_line"]
            sleep(LOG_SLEEP_TIME_W)
          end
        end

        t2 = Thread.new do
          # ramp up time
          begin
            if options.more?
              system("tail -f #{file_path} | more")
            else
              # needed ramp up time for t1 to start writting to file
              while not file_ready
                sleep(0.5)
              end
              system("less +F #{file_path}")
            end
          ensure
            # wheter application resolves normaly or is interrupted
            # t1 will be killed
            t1.exit()
          end
        end
        
        t1.join()
        t2.join()
      rescue Interrupt
        t2.exit()
      rescue DTK::Client::DtkError => e
        t2.exit()
        raise e
      end
    end

    desc "WORKSPACE-NAME/ID grep LOG-PATH NODE-ID-PATTERN GREP-PATTERN [--first]","Grep log from multiple nodes. --first option returns first match (latest log entry)."
    method_option :first, :type => :boolean, :default => false
    def grep(context_params) 
      if context_params.is_there_identifier?(:node)
        mapping = [:workspace_id!,:option_1!,:node_id!,:option_2!]
      else
        mapping = [:workspace_id!,:option_1!,:option_2!,:option_3!]
      end

      workspace_id,log_path,node_pattern,grep_pattern = context_params.retrieve_arguments(mapping,method_argument_names)
         
      begin
        post_body = {
          :assembly_id         => workspace_id,
          :subtype             => 'instance',
          :log_path            => log_path,
          :node_pattern        => node_pattern,
          :grep_pattern        => grep_pattern,
          :stop_on_first_match => options.first?
        }

        response = post rest_url("assembly/initiate_grep"), post_body

        unless response.ok?
          raise DTK::Client::DtkError, "Error while getting log from server. Message: #{response['errors'][0]['message'].nil? ? 'There was no successful response.' : response['errors'].first['message']}"
        end

        action_results_id = response.data(:action_results_id)
        action_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => true,
          :disable_post_processing => true
        }

        # number of re-tries
        3.downto(1) do
          response = post(rest_url("assembly/get_action_results"),action_body)

          # server has found an error
          unless response.data(:results).nil?
            if response.data(:results)['error']
              raise DTK::Client::DtkError, response.data(:results)['error']
            end
          end

          break if response.data(:is_complete)

          sleep(1)
        end

        raise DTK::Client::DtkError, "Error while logging there was no successful response after 3 tries." unless response.data(:is_complete)
        
        console_width = ENV["COLUMNS"].to_i

        response.data(:results).each do |r|
          raise DTK::Client::DtkError, r[1]["error"] if r[1]["error"]

          message_colorized = DTK::Client::OsUtil.colorize(r[0].inspect, :green)

          if r[1]["output"].empty?
            puts "NODE-ID #{message_colorized} - Log does not contain data that matches you pattern #{grep_pattern}!" 
          else
            puts "\n"
            console_width.times do
              print "="
            end
            puts "NODE-ID: #{message_colorized}\n"
            puts "Log output:\n"
            puts r[1]["output"].gsub(/`/,'\'')
          end
        end
      rescue DTK::Client::DtkError => e
        raise e
      end
    end

    no_tasks do


      def assembly_start(workspace_id, node_pattern_filter)             
        post_body = {
          :assembly_id  => workspace_id,
          :node_pattern => node_pattern_filter
        }

        # we expect action result ID
        response = post rest_url("assembly/start"), post_body
        raise DTK::Client::DtkValidationError, response.data(:errors).first if response.data(:errors)
        
        task_id = response.data(:task_id)
        post rest_url("task/execute"), "task_id" => task_id
      end

      def assembly_stop(workspace_id, node_pattern_filter)
        post_body = {
          :assembly_id => workspace_id,
          :node_pattern => node_pattern_filter
        }

        response = post rest_url("assembly/stop"), post_body
        raise DTK::Client::DtkValidationError, response.data(:errors).first if response.data(:errors)

        return response
      end


      def list_aux(context_params)
      workspace_id, node_id, component_id, attribute_id, about = context_params.retrieve_arguments([:workspace_id,:node_id,:component_id,:attribute_id,:option_1],method_argument_names)
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
        :assembly_id => workspace_id,
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
          data_type = :workspace_attribute
        else
          about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes"])
        end
      else
        if workspace_id
          about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes", "tasks"])
        else
          data_type = :assembly
          post_body = { :subtype  => 'instance', :detail_level => 'nodes' }
          rest_endpoint = "assembly/list"
        end  
      end

      post_body[:about] = about
      response = post rest_url(rest_endpoint), post_body

      if (data_type.to_s.eql?("workspace_attribute") && response["data"])
        response["data"].each do |data|
          unless(data["linked_to_display_form"].to_s.empty?)
            data_type = :workspace_attribute_w_link
            break
          end
        end
      end

      # set render view to be used
      response.render_table(data_type)

      return response
    end


    end
  end
end

















# dtk_require_from_base("commands/thor/assembly")

# module DTK::Client

#   class Workspace < Assembly


#     def self.get_workspace_object()
#       response = CommandBaseThor.get_cached_response(:workspace, "assembly/workspace_object", {})

#       raise DTK::Client::DtkError.new("Workspace could not be found.") if !response.ok? || response.data.first.nil?

#       response.data.first
#     end


#     no_tasks do

#       def send(symbol,*args)
#         workspace_object = Workspace.get_workspace_object()
#         args.first.add_context_to_params(:assembly, :assembly, workspace_object['id']) if args.first
#         __send__(symbol,*args)
#       end

#     end

#   end

# end