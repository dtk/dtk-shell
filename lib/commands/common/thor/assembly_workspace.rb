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

module DTK::Client
  module AssemblyWorkspaceMixin
    REQ_ASSEMBLY_OR_WS_ID = [:service_id!, :workspace_id!]
    def get_name(assembly_or_workspace_id)
      get_name_from_id_helper(assembly_or_workspace_id)
    end

    def start_aux(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:node_id]
      else
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:option_1]
      end

      assembly_or_workspace_id, node_pattern = context_params.retrieve_arguments(mapping,method_argument_names)      
      assembly_start(assembly_or_workspace_id, node_pattern)
    end

    def stop_aux(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:node_id]
      else
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:option_1]
      end

      assembly_or_workspace_id, node_pattern = context_params.retrieve_arguments(mapping,method_argument_names)
      assembly_stop(assembly_or_workspace_id, node_pattern)
    end

    def cancel_task_aux(context_params)
      assembly_or_workspace_id, task_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:option_1],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id
      }
      post_body.merge!(:task_id => task_id) if task_id
      post rest_url("assembly/cancel_task"), post_body
    end

    #mode will be :create or :update
    def promote_assembly_aux(mode,assembly_or_workspace_id,service_module_name=nil,assembly_template_name=nil)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :mode => mode.to_s
      }
      post_body.merge!(:service_module_name => service_module_name) if service_module_name
      post_body.merge!(:assembly_template_name => assembly_template_name) if assembly_template_name
      response = post rest_url("assembly/promote_to_template"), post_body
      # when changing context send request for getting latest assembly_templates instead of getting from cache
      # @@invalidate_map << :assembly_template

      return response unless response.ok?()
      #synchronize_clone will load new assembly template into service clone on workspace (if it exists)
      commit_sha,workspace_branch = response.data(:commit_sha,:workspace_branch)
      service_module_name ||= response.data(:module_name)
      Helper(:git_repo).synchronize_clone(:service_module,service_module_name,commit_sha,:local_branch=>workspace_branch)
    end

    def list_violations_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      response = post rest_url("assembly/find_violations"),:assembly_id => assembly_or_workspace_id
      response.render_table(:violation)
    end
     
    def converge_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_workspace_id
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
          return unless Console.confirmation_prompt("Workspace service is stopped, do you want to start it"+'?')
          post_body.merge!(:start_assembly=>true)
          response = post rest_url("assembly/create_task"), post_body
          return response unless response.ok?
        end
      end

      # execute task
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    def edit_module_aux(context_params)
      assembly_or_workspace_id, component_module_name = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:option_1!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :module_name => component_module_name,
        :module_type => 'component_module'
      }
      response = post rest_url("assembly/prepare_for_edit_module"), post_body
      return response unless response.ok?


      assembly_name,component_module_id,version,repo_url,branch,commit_sha = response.data(:assembly_name,:module_id,:version,:repo_url,:workspace_branch,:branch_head_sha)
      edit_opts = {
        :automatically_clone => true,
        :pull_if_needed => true,
        :assembly_module => {
          :assembly_name => assembly_name,
          :version => version
        },
        :workspace_branch_info => {
          :repo_url => repo_url,
          :branch => branch,
          :module_name => component_module_name,
          :commit_sha => commit_sha
        }
      }
      version = nil #TODO: version associated with assembly is passed in edit_opts, which is a little confusing
      edit_aux(:component_module,component_module_id,component_module_name,version,edit_opts)
    end

    def edit_workflow_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :module_type => 'service_module',
        :modification_type => 'workflow'
      }
      response = post rest_url("assembly/prepare_for_edit_module"), post_body
      return response unless response.ok?
      assembly_name,service_module_id,service_module_name,version,repo_url,branch,branch_head_sha,edit_file = response.data(:assembly_name,:module_id,:module_name,:version,:repo_url,:workspace_branch,:branch_head_sha,:edit_file)
      edit_opts = {
        :automatically_clone => true,
        :assembly_module => {
          :assembly_name => assembly_name,
          :version => version
        },
        :workspace_branch_info => {
          :repo_url => repo_url,
          :branch => branch,
          :module_name => service_module_name
        },
        :commit_sha => branch_head_sha,
        :pull_if_needed => true,
        :modification_type => :workflow,
        :edit_file => edit_file
      }
      version = nil #TODO: version associated with assembly is passed in edit_opts, which is a little confusing
      edit_aux(:service_module,service_module_id,service_module_name,version,edit_opts)
    end
    
    def edit_attributes_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      
      # if no format is set then we use 'yaml'
      format = options.format || 'yaml'
      context_params.forward_options( { :format => format})
      
      response = list_attributes_aux(context_params)
      return response unless response.ok?

      attributes_list = response.data
      attributes_hash = attributes_editor(attributes_list, format)
      
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :av_pairs_hash => attributes_hash
      }
      
      response = post rest_url("assembly/set_attributes"), post_body
    end

    def push_module_updates_aux(context_params)
      assembly_or_workspace_id, component_module_name = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:option_1!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :module_name => component_module_name,
        :module_type => 'component_module'
      }
      post_body.merge!(:force => true) if options.force?
      response = post(rest_url("assembly/promote_module_updates"),post_body)
      return response unless response.ok?
      return Response::Ok.new() unless response.data(:any_updates)
      if dsl_parsing_errors = response.data(:dsl_parsing_errors)
        #TODO: not sure if this should be reached
        error_message = "Module '#{component_module_name}' parsing errors found:\n#{dsl_parsing_errors}\nYou can fix errors using 'edit' command from module context and invoke promote-module-updates again.\n"
        OsUtil.print(dsl_parsed_message, :red) 
        return Response::Error.new()
      end
      module_name,branch,ff_change = response.data(:module_name,:workspace_branch,:fast_forward_change)
      ff_change ||= true
      opts = {:local_branch => branch}
      opts.merge!(:hard_reset => true) if !ff_change
      response = Helper(:git_repo).pull_changes?(:component_module,module_name,opts)
      return response unless response.ok?()
      Response::Ok.new()
    end

    def workflow_info_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :subtype     => 'instance'
      }
      post(rest_url("assembly/info_about_task"),post_body)
    end

    def task_status_aw_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      response = task_status_aux(assembly_or_workspace_id,:assembly,options.wait?)

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

    def link_attributes_aux(context_params)
      assembly_id, target_attr_term, source_attr_term = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => assembly_id,
        :target_attribute_term => target_attr_term,
        :source_attribute_term => source_attr_term
      }
      post rest_url("assembly/add_ad_hoc_attribute_links"), post_body
    end

    def list_nodes_aux(context_params)
      context_params.method_arguments = ["nodes"]
      list_aux(context_params)
      # list_assemblies(context_params)
    end

    def list_components_aux(context_params)
      context_params.method_arguments = ["components"]
      list_aux(context_params)
      # list_assemblies(context_params)
    end

    def list_modules_aux(context_params)
      context_params.method_arguments = ["modules"]
      list_aux(context_params)
      # list_assemblies(context_params)
    end

    def list_attributes_aux(context_params)
      context_params.method_arguments = ["attributes"]
      list_aux(context_params)
    end

    def list_tasks_aux(context_params)
      context_params.method_arguments = ["tasks"]
      list_aux(context_params)
    end

    # desc "WORKSPACE-NAME/ID list-assemblies","List assemblies for current workspace."
    # def list_assemblies(context_params)
    #   data_type = :assembly
    #   post_body = { :subtype  => 'instance', :detail_level => 'nodes' }
    #   rest_endpoint = "assembly/list"
    #   response = post rest_url(rest_endpoint), post_body

    #   response.render_table(data_type)
    #   return response
    # end

    # desc "WORKSPACE-NAME/ID list-assemblies","List assemblies for current workspace."
    # def list_assemblies(context_params)
    #   data_type = :assembly
    #   post_body = { :subtype  => 'instance', :detail_level => 'nodes' }
    #   rest_endpoint = "assembly/list"
    #   response = post rest_url(rest_endpoint), post_body

    #   response.render_table(data_type)
    #   return response
    # end

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

    def link_attribute_aux(context_params)
      assembly_or_workspace_id, target_attr_term, source_attr_term = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :target_attribute_term => target_attr_term,
        :source_attribute_term => source_attr_term
      }
      post rest_url("assembly/add_ad_hoc_attribute_links"), post_body
    end

    def list_attribute_mappings_aux(context_params)
      post_body = Helper(:service_link).post_body_with_id_keys(context_params,method_argument_names)
      post rest_url("assembly/list_attribute_mappings"), post_body
    end

    def create_component_aux(context_params)
      # If method is invoked from 'assembly/node' level retrieve node_id argument 
      # directly from active context
      if context_params.is_there_identifier?(:node)
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:node_id!,:option_1!]
      else
        # otherwise retrieve node_id from command options
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:option_1!,:option_2!]
      end

      assembly_id,node_id,component_template_id = context_params.retrieve_arguments(mapping,method_argument_names)

      post_body = {
        :assembly_id => assembly_id,
        :node_id => node_id,
        :component_template_id => component_template_id
      }

      post rest_url("assembly/add_component"), post_body
    end

    def unlink_components_aux(context_params)
      post_body = link_unlink_components__ret_post_body(context_params)
      post rest_url("assembly/delete_service_link"), post_body
    end

    def link_components_aux(context_params)
      post_body = link_unlink_components__ret_post_body(context_params)
      post rest_url("assembly/add_service_link"), post_body
    end

    def link_unlink_components__ret_post_body(context_params)
      if context_params.is_last_command_eql_to?(:component)
        assembly_or_workspace_id,dep_cmp,antec_cmp,dependency_name = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:component_id!,:option_1!,:option_2],method_argument_names)
      else
        assembly_or_workspace_id,dep_cmp,antec_cmp,dependency_name = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:option_1!,:option_2!,:option_3],method_argument_names)
      end
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :input_component_id => dep_cmp, 
        :output_component_id => antec_cmp
      }
      post_body.merge!(:dependency_name => dependency_name) if dependency_name
      post_body
    end

    def list_component_links_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id
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

    def list_connections_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :find_possible => true
      }
      response = post rest_url("assembly/list_connections"), post_body
      response.render_table(:possible_service_connection)
    end

    def list_smoketests(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_workspace_id
      }
      post rest_url("assembly/list_smoketests"), post_body
    end

    def info_aux(context_params)
      assembly_or_workspace_id, node_id, component_id, attribute_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID, :node_id, :component_id, :attribute_id],method_argument_names)
 
      post_body = {
        :assembly_id => assembly_or_workspace_id,
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

    def delete_and_destroy(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      assembly_name = get_name(assembly_or_workspace_id)

      unless options.force?
        # Ask user if really want to delete assembly, if not then return to dtk-shell without deleting
        #used form "+'?' because ?" confused emacs ruby rendering
        what = "service"
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy #{what} '#{assembly_name}' and its nodes"+'?')
      end

      #purge local clone
      response = purge_clone_aux(:all,:assembly_module => {:assembly_name => assembly_name})
      return response unless response.ok?

      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :subtype => :instance
      }

      response = post rest_url("assembly/delete"), post_body
         
      # when changing context send request for getting latest assemblies instead of getting from cache
      # @@invalidate_map << :assembly
      response
    end

    def set_target_aux(context_params)
      assembly_or_workspace_id, target_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:option_1!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :target_id => target_id
      }
      post rest_url("assembly/set_target"), post_body
    end

    def set_attribute_aux(context_params)
      if context_params.is_there_identifier?(:attribute)
        mapping = (options.unset? ? [REQ_ASSEMBLY_OR_WS_ID,:attribute_id!] : [REQ_ASSEMBLY_OR_WS_ID,:attribute_id!,:option_1!])
      else
        mapping = (options.unset? ? [REQ_ASSEMBLY_OR_WS_ID,:option_1!] : [REQ_ASSEMBLY_OR_WS_ID,:option_1!,:option_2!])
      end
      
      assembly_or_workspace_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :pattern => pattern
      }
      post_body.merge!(:value => value) unless options.unset?
      post rest_url("assembly/set_attributes"), post_body
    end

    def create_attribute_aux(context_params)
      if context_params.is_there_identifier?(:attribute)
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:attribute_id!, :option_1]
      else
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:option_1!,:option_2]
      end
      assembly_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)
      post_body = {
        :assembly_id => assembly_id,
        :pattern => pattern,
        :create => true,
      }
      post_body.merge!(:value => value) if value
      post_body.merge!(:required => true) if options.required?
      post_body.merge!(:dynamic => true) if options.dynamic?
      if datatype = options.type
        post_body.merge!(:datatype => datatype)
      end
      post rest_url("assembly/set_attributes"), post_body
    end

    def unset(context_params)
      if context_params.is_there_identifier?(:attribute)
        mapping = [[:service_id, :workspace_id!],:attribute_id!]
      else
        mapping = [[:service_id, :workspace_id!],:option_1!]
      end

      assembly_or_workspace_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)
      
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :pattern => pattern,
        :value => nil
      }
      #TODO: have this return format like assembly show attributes with subset of rows that gt changed
      post rest_url("assembly/set_attributes"), post_body
    end

    def add_assembly(context_params)
      assembly_or_workspace_id,assembly_template_id = context_params.retrieve_arguments([[:service_id, :workspace_id!],:option_1!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :assembly_template_id => assembly_template_id
      }
      post_body.merge!(:auto_add_connections => true) if options.auto_complete?
      post rest_url("assembly/add_assembly_template"), post_body
    end

    def create_node_aux(context_params)
      assembly_or_workspace_id,assembly_node_name,node_template_identifier = context_params.retrieve_arguments([[:service_id, :workspace_id!],:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :assembly_node_name => assembly_node_name
      }
      post_body.merge!(:node_template_identifier => node_template_identifier) if node_template_identifier
      post rest_url("assembly/add_node"), post_body
    end

    def purge_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      unless options.force?
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy all nodes in the workspace"+'?')
      end

      post_body = {
        :assembly_id => assembly_or_workspace_id
      }
      response = post(rest_url("assembly/purge"),post_body)
    end

    def destroy_and_reset_nodes_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      unless options.force?
        return unless Console.confirmation_prompt("Are you sure you want to destroy and reset all nodes in the workspace"+'?')
      end

      post_body = {
        :assembly_id => assembly_or_workspace_id
      }
      response = post(rest_url("assembly/destroy_and_reset_nodes"),post_body)
    end

    def delete_aux(context_params)
      if context_params.is_last_command_eql_to?(:node)
        delete_node_aux(context_params) 
      elsif context_params.is_last_command_eql_to?(:component)
        delete_component_aux(context_params)
      end
    end

    def delete_node_aux(context_params)
      assembly_or_workspace_id, node_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:option_1!],method_argument_names)
      unless options.force?
        what = "node"
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy #{what} '#{node_id}'"+'?')
      end

      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :node_id => node_id
      }
      response = post(rest_url("assembly/delete_node"),post_body)
      # @@invalidate_map << :assembly_node
      response
    end

    def delete_component_aux(context_params)
      assembly_or_workspace_id, node_id, node_name, component_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:node_id, :node_name, :option_1!],method_argument_names)

      unless options.force?
        what = "component"
        return unless Console.confirmation_prompt("Are you sure you want to delete #{what} '#{component_id}'"+'?')
      end

      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :node_id => node_id,
        :component_id => component_id
      }

      # delete component by name (e.g. delete-component dtk_java)
      post_body.merge!(:cmp_full_name => "#{node_name}/#{component_id}") if (node_name && !(component_id.to_s =~ /^[0-9]+$/))
      response = post(rest_url("assembly/delete_component"),post_body)
    end

    def get_netstats_aux(context_params)
      netstat_tries = 6
      netstat_sleep = 0.5

      assembly_or_workspace_id,node_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:node_id],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_workspace_id,
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

      #TODO: needed better way to render what is one of the fields which is any array (:results in this case)
      response.set_data(*response.data(:results))
      response.render_table(:netstat_data)
    end

    def execute_tests_aux(context_params)
      execute_test_tries = 6
      execute_test_sleep = 0.5

      assembly_or_workspace_id,node_id,component_name = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:node_id, :option_1],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :node_id => node_id
      }  

      response = post(rest_url("assembly/initiate_execute_tests"),post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => false,
          :sort_key => "module_name"
        }
        response = post(rest_url("assembly/get_action_results"),post_body)
        count += 1
        if count > execute_test_tries or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == execute_test_tries
            ret_only_if_complete = false
          end
          sleep execute_test_sleep
        end
      end

      filtered = response.data(:results)

      if !component_name.nil?
          filtered.reject! do |entry|
            entry[:component_name] != component_name
          end
      end

      response.set_data(*filtered)
      response.render_table(:execute_tests_data)
    end

    def get_ps_aux(context_params)
      get_ps_tries = 6
      get_ps_sleep = 0.5

      assembly_or_workspace_id,node_id,filter_pattern = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID,:node_id, :option_1],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_workspace_id,
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

    def set_required_params(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      set_required_params_aux(assembly_or_workspace_id,:assembly,:instance)
    end

    def tail_aux(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:node_id!,:option_1!,:option_2]
      else
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:option_1!,:option_2!,:option_3]
      end
      
      assembly_or_workspace_id,node_identifier,log_path,grep_option = context_params.retrieve_arguments(mapping,method_argument_names)
     
      last_line = nil
      begin

        file_path = File.join('/tmp',"dtk_tail_#{Time.now.to_i}.tmp")
        tail_temp_file = File.open(file_path,"a")

        file_ready = false

        t1 = Thread.new do
          while true
            post_body = {
              :assembly_id     => assembly_or_workspace_id,
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

            if response.data(:is_complete)
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
            else
              file_ready = true
              tail_temp_file << "\n\nError while logging there was no successful response after 3 tries, (^C, Q) to exit. \n\n"
              tail_temp_file.flush
              tail_temp_file.close
              Thread.current.exit
            end
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

    def grep_aux(context_params) 
      if context_params.is_there_identifier?(:node)
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:option_1!,:node_id!,:option_2!]
      else
        mapping = [REQ_ASSEMBLY_OR_WS_ID,:option_1!,:option_2!,:option_3!]
      end

      assembly_or_workspace_id,log_path,node_pattern,grep_pattern = context_params.retrieve_arguments(mapping,method_argument_names)
         
      begin
        post_body = {
          :assembly_id         => assembly_or_workspace_id,
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
      assembly_or_workspace_id, node_id, component_id, attribute_id, about = context_params.retrieve_arguments([[:service_id!, :workspace_id],:node_id,:component_id,:attribute_id,:option_1],method_argument_names)
      detail_to_include = nil
      format = nil
      post_options = Hash.new

      # use_default is used if we want to use provided data_type and not data_type returned from server
      use_default = false

      # if list method is called outside of dtk-shell and called for workspace context (dtk workspace list-nodes)
      # without workspace identifier, we will set 'workspace' as identifier (dtk workspace workspace list-nodes)
      assembly_or_workspace_id = 'workspace' if (context_params.is_last_command_eql_to?(:workspace) && assembly_or_workspace_id.nil?)

      #TODO: looking for cleaner way of showing which ones are using the default datatype passed back from server;
      #might use data_type = DynamicDatatype
      if about
        case about
          when "nodes"
            data_type = :node
          when "components"
            data_type = :component
            if options.deps?
              detail_to_include = [:component_dependencies]
            end  
          when "attributes"
            data_type = (options.links? ? :workspace_attribute_w_link : :workspace_attribute)
            edit_attr_format = context_params.get_forwarded_options()[:format] if context_params.get_forwarded_options()
            if format = (options.format || edit_attr_format)
              post_options.merge!(:format => format)
              #dont need to compute links if using a format
            elsif options.links?
              detail_to_include = [:attribute_links]
            end
          when "modules"
             detail_to_include = [:version_info]
             data_type = nil #TODO: DynamicDatatype
          when "tasks"
            data_type = :task
          else
            raise_validation_error_method_usage('list')
        end 
      end

      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :node_id => node_id,
        :component_id => component_id,
        :subtype     => 'instance',
      }.merge(post_options)

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
        if assembly_or_workspace_id
          about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes", "modules","tasks"])
          
          if data_type.to_s.eql?("component")
            data_type = nil #DynamicDatatype
          end
          #TODO: need to cleanup that data_type set in multiple places
          if about == "attributes"
            data_type = (options.links? ? :workspace_attribute_w_link : :workspace_attribute)
          end
        else
          data_type = :assembly
          post_body = { :subtype  => 'instance', :detail_level => 'nodes' }
          rest_endpoint = "assembly/list"
        end  
      end

      post_body[:about] = about
      response = post rest_url(rest_endpoint), post_body
      # set render view to be used
      unless format
        response.render_table(data_type, use_default)
      end

      response
    end

    def clear_tasks_aux(context_params)
      assembly_or_workspace_id = context_params.retrieve_arguments([REQ_ASSEMBLY_OR_WS_ID],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_workspace_id
      }
      post rest_url("assembly/clear_tasks"), post_body
    end

  end
end
