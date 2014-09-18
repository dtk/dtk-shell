dtk_require_from_base("shell/status_monitor")
dtk_require_common_commands('thor/assembly_template')
module DTK::Client
  class Assembly < CommandBaseThor
    no_tasks do
      include AssemblyTemplateMixin
    end

    def self.whoami()
      return :assembly, "assembly/list", {:subtype  => 'template'}
    end

    def self.get_assembly_template_id_for_service(assembly_template_name, service)
      assembly_template_id = nil
      # TODO: See with Rich if there is better way to resolve this
      response = DTK::Client::CommandBaseThor.get_cached_response(:assembly, "assembly/list", {:subtype => 'template' })
      # response = DTK::Client::CommandBaseThor.get_cached_response(:module, "service_module/list")

      service_namespace = service.split(":").first
      service_name = service.split(":").last

      if response.ok?
        unless response['data'].nil?
          response['data'].each do |module_item|
            if ("#{service_name.to_s}::#{assembly_template_name.to_s}" == (module_item['display_name']) && service_namespace == module_item['namespace'])
              assembly_template_id = module_item['id']
              break
            end
          end
        end
      end

      raise DTK::Client::DtkError, "Illegal name (#{assembly_template_name}) for assembly." if assembly_template_id.nil?
      
      return assembly_template_id
    end

    def self.get_assembly_template_name_for_service(assembly_template_id, service)
      assembly_template_name = nil
      # TODO: See with Rich if there is better way to resolve this
      response = DTK::Client::CommandBaseThor.get_cached_response(:assembly, "assembly/list", {:subtype => 'template' })

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

      raise DTK::Client::DtkError, "Illegal name (#{assembly_template_name}) for assembly." if assembly_template_name.nil?
      return assembly_template_name
    end

    def self.pretty_print_cols()
      PPColumns.get(:assembly)
    end


    # List assembly templates for specific module
    def self.validation_list(context_params)
      if context_params.is_there_identifier?(:"service-module")
        service_module_id = context_params.retrieve_arguments([:service_module_id!])
        get_cached_response(:assembly, "service_module/list_assemblies", { :service_module_id => service_module_id })
      else
        get_cached_response(:assembly, "assembly/list", {:subtype => 'template' })
      end
    end

    def self.assembly_list()
      assembly_list = []
      response = get_cached_response(:service, "assembly/list", {})
      raise DTK::Client::DtkError, "Unable to retreive service list." unless (response.nil? || response.ok?)
      
      if assemblies = response.data
        assemblies.each do |assembly|
          assembly_list << assembly["display_name"]
        end
      end
      
      assembly_list
    end

    desc "ASSEMBLY-NAME/ID info", "Get information about given assembly."
    method_option :list, :type => :boolean, :default => false
    def info(context_params)
      assembly_template_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)
      data_type = :assembly_template
      
      post_body = {
        :assembly_id => assembly_template_id,
        :subtype => 'template',
      }
      
      post rest_url("assembly/info"), post_body
    end

    desc "ASSEMBLY-NAME/ID list-nodes [--service SERVICE-NAME]", "List all nodes for given assembly."
    method_option :list, :type => :boolean, :default => false
    method_option "service",:aliases => "-s" ,
      :type => :string, 
      :banner => "SERVICE-LIST-FILTER",
      :desc => "Service list filter"
    def list_nodes(context_params)
      context_params.method_arguments = ["nodes"]
      list(context_params)
    end

    desc "ASSEMBLY-NAME/ID list-components [--service SERVICE-NAME]", "List all components for given assembly."
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
    desc "list", "List all assemblies."
    def list(context_params)
      assembly_template_id, about, service_filter = context_params.retrieve_arguments([:assembly_id, :option_1, :option_1],method_argument_names)

      if assembly_template_id.nil?

        if options.service
          service_id = options.service
          context_params_for_service = DTK::Shell::ContextParams.new
          context_params_for_service.add_context_to_params("service_module", "service_module", service_id)
          context_params_for_service.method_arguments = ['assembly',"#{service_id}"]
          
          response = DTK::Client::ContextRouter.routeTask("service_module", "list", context_params_for_service, @conn)
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

    desc "ASSEMBLY-NAME/ID list-settings", "List all settings for given assembly."
    def list_settings(context_params)
      assembly_template_id = context_params.retrieve_arguments([:assembly_id!],method_argument_names)

      post_body = {
        :assembly_id => assembly_template_id
      }

      response = post rest_url("assembly/list_settings"), post_body
      response.render_table(:service_setting) unless options.list?

      response
    end

    desc "ASSEMBLY-NAME/ID stage [INSTANCE-NAME] [-t TARGET-NAME/ID] [--settings SETTINGS-NAME1[,..]]", "Stage assembly in target."
    method_option "in-target",:aliases => "-t" ,
      :type => :string, 
      :banner => "TARGET-NAME/ID",
      :desc => "Target (id) to create assembly in" 
    #hidden option
    method_option "instance-bindings",
      :type => :string 
    method_option :settings, :type => :string, :aliases => '-s'
    def stage(context_params)
      assembly_template_id, name = context_params.retrieve_arguments([:assembly_id!, :option_1],method_argument_names)
      post_body = {
        :assembly_id => assembly_template_id
      }

      # using this to make sure cache will be invalidated after new assembly is created from other commands e.g.
      # 'assembly-create', 'install' etc.
      @@invalidate_map << :assembly
      
      assembly_template_name = get_assembly_name(assembly_template_id)
      assembly_template_name.gsub!('::','-') if assembly_template_name

      in_target = options["in-target"]
      instance_bindings = options["instance-bindings"]
      settings = parse_service_settings(options["settings"])
      assembly_list = Assembly.assembly_list()

      if name
        raise DTK::Client::DtkValidationError, "Unable to stage service with name '#{name}'. Service with specified name exists already!" if assembly_list.include?(name)
      else
        name = get_assembly_stage_name(assembly_list,assembly_template_name)
      end
      
      post_body.merge!(:target_id => in_target) if in_target
      post_body.merge!(:name => name) if name
      post_body.merge!(:instance_bindings => instance_bindings) if instance_bindings
      post_body.merge!(:settings_json_form => JSON.generate(settings)) if settings

      response = post rest_url("assembly/stage"), post_body
      return response unless response.ok?
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :service
      @@invalidate_map << :assembly

      return response
    end


#    desc "ASSEMBLY-NAME/ID deploy [INSTANCE-NAME] [-t TARGET-NAME/ID] [--settings SETTINGS-NAME1[,..]]", "Stage assembly in target."
#     version_method_option
    desc "ASSEMBLY-NAME/ID deploy [INSTANCE-NAME] [--settings SETTINGS-NAME1[,..]] [-m COMMIT-MSG]", "Stage and deploy assembly in target."
    #hidden option
    method_option "instance-bindings",
      :type => :string 
#    method_option "in-target",:aliases => "-t" ,
#      :type => :string,
#      :banner => "TARGET-NAME/ID",
#      :desc => "Target (id) to create assembly in" 
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    method_option :settings, :type => :string, :aliases => '-s'
    def deploy(context_params)
      context_params.forward_options(options)
      assembly_template_id, name = context_params.retrieve_arguments([:assembly_id!, :option_1],method_argument_names)
      post_body = {
        :assembly_id => assembly_template_id
      }
      if commit_msg = options["commit_msg"]
        post_body.merge!(:commit_msg => commit_msg)
      end

      # using this to make sure cache will be invalidated after new assembly is created from other commands e.g.
      # 'assembly-create', 'install' etc.
      @@invalidate_map << :assembly
      
      assembly_template_name = get_assembly_name(assembly_template_id)
      assembly_template_name.gsub!('::','-') if assembly_template_name

      # we check current options and forwarded options (from deploy method)
      in_target = options["in-target"] || context_params.get_forwarded_thor_option("in-target")
      instance_bindings = options["instance-bindings"]
      settings = options["settings"]
      assembly_list = Assembly.assembly_list()

      if name
        raise DTK::Client::DtkValidationError, "Unable to deploy service with name '#{name}'. Service with specified name exists already!" if assembly_list.include?(name)
      else
        name = get_assembly_stage_name(assembly_list,assembly_template_name)
      end
      
      post_body.merge!(:target_id => in_target) if in_target
      post_body.merge!(:name => name) if name
      post_body.merge!(:instance_bindings => instance_bindings) if instance_bindings
      post_body.merge!(:settings_json_form => JSON.generate(settings)) if settings

      response = post rest_url("assembly/deploy"), post_body
      return response unless response.ok?
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :service
      @@invalidate_map << :assembly
      response
    end
 

    desc "delete ASSEMBLY-ID", "Delete assembly"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete(context_params)
      assembly_template_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      unless options.force?
        # Ask user if really want to delete assembly-template, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete assembly '#{assembly_template_id}'"+"?")
      end

      post_body = {
        :assembly_id => assembly_template_id,
        :subtype => :template
      }
      response = post rest_url("assembly/delete"), post_body
      
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly
      return response unless response.ok?
      module_name,branch = response.data(:module_name,:workspace_branch)
      response = Helper(:git_repo).pull_changes?(:service_module,module_name,:local_branch => branch)
      return response unless response.ok?()
      Response::Ok.new()
    end
  end
end
