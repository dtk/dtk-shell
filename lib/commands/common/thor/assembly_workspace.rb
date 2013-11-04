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

    def get_name(assembly_id)
      get_name_from_id_helper(assembly_id)
    end

    def start_aux(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [[:assembly_id!, :workspace_id!],:node_id]
      else
        mapping = [[:assembly_id!, :workspace_id!],:option_1]
      end

      assembly_or_worspace_id, node_pattern = context_params.retrieve_arguments(mapping,method_argument_names)      
      assembly_start(assembly_or_worspace_id, node_pattern)
    end

    def stop_aux(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [[:assembly_id!, :workspace_id!],:node_id]
      else
        mapping = [[:assembly_id!, :workspace_id!],:option_1]
      end

      assembly_or_worspace_id, node_pattern = context_params.retrieve_arguments(mapping,method_argument_names)
      assembly_stop(assembly_or_worspace_id, node_pattern)
    end

    def cancel_task_aux(context_params)
      task_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      cancel_task_aux(task_id)
    end

    def create_assembly_aux(context_params)
      assembly_or_worspace_id, service_module_name, assembly_template_name = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_worspace_id,
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
    
    def list_violations_aux(context_params)
      assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)
      response = post rest_url("assembly/find_violations"),:assembly_id => assembly_or_worspace_id
      response.render_table(:violation)
    end
     
    def converge_aux(context_params)
      assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_worspace_id
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

    def edit_module_aux(context_params)
      assembly_or_worspace_id, component_module_name = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:option_1!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_worspace_id,
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

    def promote_module_updates_aux(context_params)
      assembly_or_worspace_id, component_module_name = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:option_1!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :module_name => component_module_name,
        :module_type => 'component_module'
      }
      response = post(rest_url("assembly/promote_module_updates"),post_body)
      return response unless response.ok?
      return Response::Ok.new() unless response.data(:any_updates)
      if dsl_parsing_errors = response.data(:dsl_parsing_errors)
        error_message = "Module '#{component_module_name}' imported with errors:\n#{dsl_parsing_errors}\nYou can fix errors and import module again.\n"
        OsUtil.print(dsl_parsed_message, :red) 
        return Response::Error.new()
      end
      module_name,branch = response.data(:module_name,:workspace_branch)
      response = Helper(:git_repo).pull_changes?(:component_module,module_name,:local_branch => branch)
      return response unless response.ok?()
      Response::Ok.new()
    end

    def list_task_info_aux(context_params)
      assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)
      #TODO: deprecate this method: list_task_info_aux("assembly", workspace_id)
      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :subtype     => 'instance'
      }
      response = post(rest_url("assembly/info_about_task"),post_body)
      response
    end

    def task_status_aux(context_params)
      assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)
      response = task_status_aux(assembly_or_worspace_id,:assembly,options.wait?)

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

    def list_attributes_aux(context_params)
      context_params.method_arguments = ["attributes"]
      list_aux(context_params)
      # list_assemblies(context_params)
    end

    def list_tasks_aux(context_params)
      context_params.method_arguments = ["tasks"]
      list_aux(context_params)
      # list_assemblies(context_params)
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

    def link_attribute_to_aux(context_params)
      assembly_or_worspace_id, target_attr_term, source_attr_term = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :target_attribute_term => target_attr_term,
        :source_attribute_term => source_attr_term
      }
      post rest_url("assembly/add_ad_hoc_attribute_links"), post_body
    end

    def list_attribute_mappings_aux(context_params)
      post_body = Helper(:service_link).post_body_with_id_keys(context_params,method_argument_names)
      post rest_url("assembly/list_attribute_mappings"), post_body
    end

    def create_attribute_aux(context_params)
      post_body = Helper(:service_link).post_body_with_id_keys(context_params,method_argument_names)
      base_attr,arrow,dep_attr = context_params.retrieve_arguments([:option_2!,:option_3!,:option_4!],method_argument_names)
      post_body.merge!(:attribute_mapping => "#{base_attr} #{arrow} #{dep_attr}") #TODO: probably change to be hash
      post rest_url("assembly/add_ad_hoc_attribute_mapping"), post_body
    end

    def delete_service_link_aux(context_params)
      post_body = Helper(:service_link).post_body_with_id_keys(context_params,method_argument_names)
      post rest_url("assembly/delete_service_link"), post_body
    end

    def create_service_link_aux(context_params)
      if context_params.is_last_command_eql_to?(:component)
        assembly_or_worspace_id,service_type,base_cmp,dep_cmp = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:option_1!,:component_id!,:option_2!],method_argument_names)
      else
        assembly_or_worspace_id,service_type,base_cmp,dep_cmp = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:option_1!,:option_2!,:option_3!],method_argument_names)
      end

      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :service_type => service_type,
        :input_component_id => base_cmp, 
        :output_component_id => dep_cmp
      }
      post rest_url("assembly/add_service_link"), post_body
    end

    def list_service_links_aux(context_params)
      assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_worspace_id
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
      assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :find_possible => true
      }
      response = post rest_url("assembly/list_connections"), post_body
      response.render_table(:possible_service_connection)
    end

    def list_smoketests(context_params)
      assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_worspace_id
      }
      post rest_url("assembly/list_smoketests"), post_body
    end

    def info_aux(context_params)
      assembly_or_worspace_id, node_id, component_id, attribute_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!], :node_id, :component_id, :attribute_id],method_argument_names)
 
      post_body = {
        :assembly_id => assembly_or_worspace_id,
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
      assembly_or_worspace_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      assembly_name = get_assembly_name(assembly_or_worspace_id)

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
        :assembly_id => assembly_or_worspace_id,
        :subtype => :instance
      }

      response = post rest_url("assembly/delete"), post_body
         
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly
      response
    end

    def  set_attribute_aux(context_params)
      if options.required?
        assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)
        return set_required_params_aux(assembly_or_worspace_id,:assembly,:instance)
      end

      if context_params.is_there_identifier?(:attribute)
        mapping = (options.unset? ? [[:assembly_id!, :workspace_id!],:attribute_id!] : [[:assembly_id!, :workspace_id!],:attribute_id!,:option_1!])
      else
        mapping = (options.unset? ? [[:assembly_id!, :workspace_id!],:option_1!] : [[:assembly_id!, :workspace_id!],:option_1!,:option_2!])
      end
      
      assembly_or_worspace_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)
      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :pattern => pattern,
        :value => value
      }
      #TODO: have this return format like assembly show attributes with subset of rows that gt changed
      post rest_url("assembly/set_attributes"), post_body
    end

    def create_attribute_aux(context_params)
      if context_params.is_there_identifier?(:attribute)
        mapping = [[:assembly_id!, :workspace_id!],:attribute_id!, :option_1]
      else
        mapping = [[:assembly_id!, :workspace_id!],:option_1!,:option_2]
      end
      assembly_or_worspace_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)
      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :pattern => pattern,
        :create => true,
      }
      post_body.merge!(:value => value) if value

      #TODO: have this return format like assembly show attributes with subset of rows that gt changed
      post rest_url("assembly/set_attributes"), post_body
    end

    def unset(context_params)
      if context_params.is_there_identifier?(:attribute)
        mapping = [[:assembly_id, :workspace_id!],:attribute_id!]
      else
        mapping = [[:assembly_id, :workspace_id!],:option_1!]
      end

      assembly_or_worspace_id, pattern, value = context_params.retrieve_arguments(mapping,method_argument_names)
      
      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :pattern => pattern,
        :value => nil
      }
      #TODO: have this return format like assembly show attributes with subset of rows that gt changed
      post rest_url("assembly/set_attributes"), post_body
    end

    def add_assembly(context_params)
      assembly_or_worspace_id,assembly_template_id = context_params.retrieve_arguments([[:assembly_id, :workspace_id!],:option_1!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :assembly_template_id => assembly_template_id
      }
      post_body.merge!(:auto_add_connections => true) if options.auto_complete?
      post rest_url("assembly/add_assembly_template"), post_body
    end

    def create_node_aux(context_params)
      assembly_or_worspace_id,assembly_node_name,node_template_identifier = context_params.retrieve_arguments([[:assembly_id, :workspace_id!],:option_1!,:option_2!],method_argument_names)
      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :assembly_node_name => assembly_node_name
      }
      post_body.merge!(:node_template_identifier => node_template_identifier) if node_template_identifier
      response = post rest_url("assembly/add_node"), post_body

      @@invalidate_map << :assembly_node
      return response
    end

    def purge_aux(context_params)
      assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)
      unless options.force?
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy all nodes in the workspace"+'?')
      end

      post_body = {
        :assembly_id => assembly_or_worspace_id
      }
      response = post(rest_url("assembly/purge"),post_body)
    end

    def add_component_aux(context_params)
    
      # If method is invoked from 'assembly/node' level retrieve node_id argument 
      # directly from active context
      if context_params.is_there_identifier?(:node)
        mapping = [[:assembly_id!, :workspace_id!],:node_id!,:option_1!,:option_2]
      else
        # otherwise retrieve node_id from command options
        mapping = [[:assembly_id!, :workspace_id!],:option_1!,:option_2!,:option_3]
      end

      assembly_or_worspace_id,node_id,component_template_id,order_index = context_params.retrieve_arguments(mapping,method_argument_names)

      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :node_id => node_id,
        :component_template_id => component_template_id,
        :order_index => order_index
      }

      response = post(rest_url("assembly/add_component"), post_body)
      return response unless response.ok?

      puts "Successfully added component to node."
    end

    def delete_aux(context_params)
    delete_node_aux(context_params) if context_params.is_last_command_eql_to?(:node)   
    delete_component_aux(context_params) if context_params.is_last_command_eql_to?(:component)
    end

    def delete_node_aux(context_params)
      assembly_or_worspace_id, node_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:option_1!],method_argument_names)
      unless options.force?
        what = "node"
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy #{what} '#{node_id}'"+'?')
      end

      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :node_id => node_id
      }
      response = post(rest_url("assembly/delete_node"),post_body)
      @@invalidate_map << :assembly_node
      response
    end

    def delete_component_aux(context_params)
      assembly_or_worspace_id, node_id, component_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:node_id,:option_1!],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_worspace_id,
        :node_id => node_id,
        :component_id => component_id
      }
      response = post(rest_url("assembly/delete_component"),post_body)
      @@invalidate_map << :assembly_node_component
      response
    end

    def edit_aux(context_params)
      assembly_or_worspace_id, component_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!], :component_id!], method_argument_names)

      post_body = {
        :assembly_id => assembly_or_worspace_id,
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

    def get_netstats_aux(context_params)
      netstat_tries = 6
      netstat_sleep = 0.5

      assembly_or_worspace_id,node_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:node_id],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_worspace_id,
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

    def get_ps_aux(context_params)
      get_ps_tries = 6
      get_ps_sleep = 0.5

      assembly_or_worspace_id,node_id,filter_pattern = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!],:node_id, :option_1],method_argument_names)

      post_body = {
        :assembly_id => assembly_or_worspace_id,
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
      assembly_or_worspace_id = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!]],method_argument_names)
      set_required_params_aux(assembly_or_worspace_id,:assembly,:instance)
    end

    def tail_aux(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [[:assembly_id!, :workspace_id!],:node_id!,:option_1!,:option_2]
      else
        mapping = [[:assembly_id!, :workspace_id!],:option_1!,:option_2!,:option_3]
      end
      
      assembly_or_worspace_id,node_identifier,log_path,grep_option = context_params.retrieve_arguments(mapping,method_argument_names)
     
      last_line = nil
      begin

        file_path = File.join('/tmp',"dtk_tail_#{Time.now.to_i}.tmp")
        tail_temp_file = File.open(file_path,"a")

        file_ready = false

        t1 = Thread.new do
          while true
            post_body = {
              :assembly_id     => assembly_or_worspace_id,
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

    def grep_aux(context_params) 
      if context_params.is_there_identifier?(:node)
        mapping = [[:assembly_id!, :workspace_id!],:option_1!,:node_id!,:option_2!]
      else
        mapping = [[:assembly_id!, :workspace_id!],:option_1!,:option_2!,:option_3!]
      end

      assembly_or_worspace_id,log_path,node_pattern,grep_pattern = context_params.retrieve_arguments(mapping,method_argument_names)
         
      begin
        post_body = {
          :assembly_id         => assembly_or_worspace_id,
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
      # assembly_or_worspace_id, node_id, node_name = context_params.retrieve_arguments([[:assembly_id!, :workspace_id!], :node_id!, :node_name!])

      assembly_or_worspace_id, node_id, component_id, attribute_id, about = context_params.retrieve_arguments([[:assembly_id, :workspace_id],:node_id,:component_id,:attribute_id,:option_1],method_argument_names)
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
        :assembly_id => assembly_or_worspace_id,
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
        if assembly_or_worspace_id
          about, data_type = get_type_and_raise_error_if_invalid(about, "nodes", ["attributes", "components", "nodes", "tasks"])
        else
          data_type = :assembly
          post_body = { :subtype  => 'instance', :detail_level => 'nodes' }
          rest_endpoint = "assembly/list"
        end  
      end

      post_body[:about] = about
      response = post rest_url(rest_endpoint), post_body

      if (data_type.to_s.eql?("attribute") && response["data"])
        data_type = :workspace_attribute
        response["data"].each do |data|
          unless (data["linked_to_display_form"].to_s.empty?)
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