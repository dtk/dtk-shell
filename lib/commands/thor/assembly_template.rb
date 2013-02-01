dtk_require("../../shell/status_monitor")

module DTK::Client
  class AssemblyTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:assembly_template)
    end

    def self.whoami()
      return :assembly_template, "assembly/list", {:subtype => 'template'}
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

#    desc "[ASSEMBLY-TEMPLATE-NAME/ID] show [nodes|components|targets]", "List all nodes/components/targets for given assembly template."
    #TODO: temporaily taking out target option
    desc "[ASSEMBLY-TEMPLATE-NAME/ID] list [nodes|components] [--service SERVICE-NAME]", "List all nodes/components for given assembly template."
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
          response.render_table(data_type)
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
        else
          raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
        end

        response.render_table(data_type) unless options.list?

        response
      end
    end

    desc "ASSEMBLY-TEMPLATE-NAME/ID stage [-v VERSION] [INSTANCE-NAME]", "Stage assembly template in target."
    version_method_option
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create assembly in" 
    def stage(context_params)
      assembly_template_id, name = context_params.retrieve_arguments([:assembly_template_id!, :option_1],method_argument_names)
      version = options["version"]
      post_body = {
        :assembly_id => assembly_template_id
      }
      post_body.merge!(:version => version) if version
      post_body.merge!(:target_id => options["in-target"]) if options["in-target"]
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
      response = stage(context_params)

      return response unless response.ok?

      # create task      
      assembly_id = response.data(:assembly_id)
      post_body = {
        :assembly_id => assembly_id,
        :commit_msg => options["commit_msg"]||"Initial deploy"
      }

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

