dtk_require("../../shell/status_monitor")

module DTK::Client
  class AssemblyTemplate < CommandBaseThor

    def self.get_assembly_template_id_for_service(assembly_template_name, service)
      assembly_template_id = nil
      # TODO: See with Rich if there is better way to resolve this
      response = DTK::Client::CommandBaseThor.get_cached_response(:assembly_template, "assembly/list", {:subtype => 'template' })
      # response = DTK::Client::CommandBaseThor.get_cached_response(:module, "service_module/list")

      if response.ok?
        unless response['data'].nil?
          response['data'].each do |module_item|
            if ("#{service.to_s}::#{assembly_template_name.to_s}" == (module_item['display_name']))
              assembly_template_id = module_item['id']
              break
            end
          end
        end
      end

      raise DTK::Client::DtkError, "Illegal name (#{assembly_template_name}) for template." if assembly_template_id.nil?
      
      return assembly_template_id
    end

    def self.get_assembly_template_name_for_service(assembly_template_id, service)
      assembly_template_name = nil
      # TODO: See with Rich if there is better way to resolve this
      response = DTK::Client::CommandBaseThor.get_cached_response(:assembly_template, "assembly/list", {:subtype => 'template' })

      if response.ok?
        unless response['data'].nil?
          response['data'].each do |module_item|
            if assembly_template_id.to_i == module_item['id']
              assembly_template_name = module_item['display_name'].gsub("#{service.to_s}::",'')
              break
            end
          end
        end
      end

      raise DTK::Client::DtkError, "Illegal name (#{assembly_template_name}) for template." if assembly_template_name.nil?
      return assembly_template_name
    end

    def self.pretty_print_cols()
      PPColumns.get(:assembly_template)
    end


    # List assembly templates for specific module
    def self.validation_list(context_params)
      if context_params.is_there_identifier?(:service)
        service_module_id = context_params.retrieve_arguments([:service_id!], [])
        get_cached_response(:assembly_template, "service_module/list_assemblies", { :service_module_id => service_module_id })
      else
        get_cached_response(:assembly_template, "assembly/list", {:subtype => 'template' })
      end
    end

    desc "ASSEMBLY-TEMPLATE-NAME/ID info", "Get information about given assembly template."
    method_option :list, :type => :boolean, :default => false
    def info(context_params)
      assembly_template_id = context_params.retrieve_arguments([:assembly_template_id!],method_argument_names)

      data_type = :assembly_template
      
      post_body = {
        :assembly_id => assembly_template_id,
        :subtype => 'template',
      }
      post rest_url("assembly/info"), post_body
    end

    desc "ASSEMBLY-TEMPLATE-NAME/ID list-nodes [--service SERVICE-NAME]", "List all nodes for given assembly template."
    method_option :list, :type => :boolean, :default => false
    method_option "service",:aliases => "-s" ,
      :type => :string, 
      :banner => "SERVICE-LIST-FILTER",
      :desc => "Service list filter"
    def list_nodes(context_params)
      context_params.method_arguments = ["nodes"]
      list(context_params)
    end

    desc "ASSEMBLY-TEMPLATE-NAME/ID list-components [--service SERVICE-NAME]", "List all components for given assembly template."
    method_option :list, :type => :boolean, :default => false
    method_option "service",:aliases => "-s" ,
      :type => :string, 
      :banner => "SERVICE-LIST-FILTER",
      :desc => "Service list filter"
    def list_components(context_params)
      context_params.method_arguments = ["components"]
      list(context_params)
    end

#    desc "[ASSEMBLY-TEMPLATE-NAME/ID] show [nodes|components|targets]", "List all nodes/components/targets for given assembly template."
    #TODO: temporaily taking out target option
    desc "list [--service SERVICE-NAME]", "List all assembly templates."
    method_option :list, :type => :boolean, :default => false
    method_option "service",:aliases => "-s" ,
      :type => :string, 
      :banner => "SERVICE-LIST-FILTER",
      :desc => "Service list filter"
    def list(context_params)
      assembly_template_id, about, service_filter = context_params.retrieve_arguments([:assembly_template_id, :option_1, :option_1],method_argument_names)

      if assembly_template_id.nil?

        if options.service
          # Special case when user sends --service; until now --OPTION didn't have value attached to it
          if options.service.eql?("service")
            service_id = service_filter
          else 
            service_id = options.service
          end

          context_params_for_service = DTK::Shell::ContextParams.new
          context_params_for_service.add_context_to_params("service", "service", service_id)
          context_params_for_service.method_arguments = ['list']
          
          response = DTK::Client::ContextRouter.routeTask("service", "assembly_template", context_params_for_service, @conn)

        else
          response = post rest_url("assembly/list"), {:subtype => 'template', :detail_level => 'nodes'}
          data_type = :assembly_template
          response.render_table(data_type) unless options.list?
          return response
        end

      else
        
        post_body = {
          :subtype => 'template',
          :assembly_id => assembly_template_id,
          :about => about
        }

        case about
        when 'nodes'
          response = post rest_url("assembly/info_about"), post_body
          data_type = :node_template
        when 'components'
          response = post rest_url("assembly/info_about"), post_body
          data_type = :component
        # when 'attributes'
          # response = post rest_url("assembly/info_about"), post_body
          # data_type = :attribute
        else
          raise_validation_error_method_usage('list')
        end

        response.render_table(data_type) unless options.list?

        return response
      end
    end

    desc "ASSEMBLY-TEMPLATE-NAME/ID stage [INSTANCE-NAME] -t [TARGET-NAME/ID]", "Stage assembly template in target."
    method_option "in-target",:aliases => "-t" ,
      :type => :string, 
      :banner => "TARGET-NAME/ID",
      :desc => "Target (id) to create assembly in" 
    def stage(context_params)
      assembly_template_id, name = context_params.retrieve_arguments([:assembly_template_id!, :option_1],method_argument_names)
      post_body = {
        :assembly_id => assembly_template_id
      }



      # we check current options and forwarded options (from deploy method)
      in_target = options["in-target"] || context_params.get_forwarded_thor_option("in-target")

      post_body.merge!(:target_id => in_target) if in_target
      post_body.merge!(:name => name) if name
      response = post rest_url("assembly/stage"), post_body
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly

      return response
    end

    desc "ASSEMBLY-TEMPLATE-NAME/ID deploy [-v VERSION] [INSTANCE-NAME] [-m COMMIT-MSG]", "Stage and deploy assembly template in target."
    version_method_option
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create assembly in" 
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def deploy(context_params)
      context_params.forward_options(options)
      response = stage(context_params)

      return response unless response.ok?

      # create task      
      assembly_id = response.data(:assembly_id)
      post_body = {
        :assembly_id => assembly_id,
        :commit_msg => options["commit_msg"]||"Initial deploy"
      }

      response = post rest_url("assembly/find_violations"), post_body
      return response unless response.ok?
      if response.data and response.data.size > 0
        error_message =  "The following violations were found; they must be corrected before the assembly-template can be deployed"
        DTK::Client::OsUtil.print(error_message, :red)
        return response.render_table(:violation)
      end

      ret = response = post(rest_url("assembly/create_task"), post_body)        

      return response unless response.ok?

      # execute task
      task_id = response.data(:task_id)
      response = post(rest_url("task/execute"), "task_id" => task_id)

      # start watching task ID
      if $shell_mode
        DTK::Shell::StatusMonitor.start_monitoring(task_id) if response.ok?
      end

      return response unless response.ok?
      ret.add_data_value!(:task_id,task_id)

      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly

      return ret
    end


    desc "delete ASSEMBLY-TEMPLATE-ID", "Delete assembly template"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete(context_params)
      assembly_template_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      unless options.force?
        # Ask user if really want to delete assembly-template, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete assembly-template '#{assembly_template_id}'"+"?")
      end

      post_body = {
        :assembly_id => assembly_template_id,
        :subtype => :template
      }
      response = post rest_url("assembly/delete"), post_body
      
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly_template
      return response unless response.ok?
      module_name,branch = response.data(:module_name,:workspace_branch)
      Helper(:git_repo).pull_changes?(:service_module,module_name,:local_branch => branch)
    end
  end
end

