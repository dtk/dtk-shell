module DTK::Client
  class ComponentTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:component)
    end

    def self.valid_children()
      # Amar: attribute context commented out per Rich suggeston
      #[:attribute]
      []
    end

    # this includes children of children
    def self.all_children()
      # Amar: attribute context commented out per Rich suggeston
      #[:attribute]
      []
    end

    def self.valid_child?(name_of_sub_context)
      return ComponentTemplate.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      if context_params.is_there_identifier?(:module)
        component_module_id = context_params.retrieve_arguments([:module_id!])
        res = get_cached_response(:component_template, "component_module/info_about", { :component_module_id => component_module_id, :about => :components})
      else
        get_cached_response(:component_template, "component/list", {:subtype => 'template'})
      end
    end

     def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({})
      # Amar: attribute context commented out per Rich suggeston
      #return DTK::Shell::OverrideTasks.new(
      #  {
      #    :command_only => {
      #      :attribute => [
      #        ['list',"list","List attributes for given component"]
      #      ]
      #    },
      #    :identifier_only => {
      #      :attribute => [
      #        ['list',"list","List attributes for given component"]
      #      ]
      #    }
      #
      #})
    end

    desc "COMPONENT-TEMPLATE-NAME/ID info", "Get information about given component template."
    method_option :list, :type => :boolean, :default => false
    def info(context_params)
      component_id = context_params.retrieve_arguments([:component_template_id!],method_argument_names)
      data_type = :component

      post_body = {
        :component_id => component_id,
        :subtype => 'template'
      }
      response = post rest_url("component/info"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "COMPONENT-TEMPLATE-NAME/ID list-nodes [--module MODULE-NAME]", "List all nodes for given component template. Optional filter by modul name."
    method_option :list, :type => :boolean, :default => false
    method_option "module",:aliases => "-m" ,
      :type => :string, 
      :banner => "MODULE-LIST-FILTER",
      :desc => "Module list filter"
    def list_nodes(context_params)
      context_params.method_arguments = ["nodes"]
      list(context_params)
    end

    desc "list [--module MODULE-NAME]", "List all component templates. Optional filter by modul name."
    method_option :list, :type => :boolean, :default => false
    method_option "module",:aliases => "-m" ,
      :type => :string, 
      :banner => "MODULE-LIST-FILTER",
      :desc => "Module list filter"
    def list(context_params)
      component_id, about, module_filter = context_params.retrieve_arguments([:component_template_id,:option_1,:option_1],method_argument_names)
      about ||= 'none'
      data_type = :component

      # Case when user provided '--module' / '-m' 'MODUL-NAME'
      if options.module
        # Special case when user sends --module; until now --OPTION didn't have value attached to it
        if options.module.eql?("module")
          module_id = module_filter
        else 
          module_id = options.module
        end

        context_params_for_service = DTK::Shell::ContextParams.new
        context_params_for_service.add_context_to_params("module", "module", module_id)
        
        response = DTK::Client::ContextRouter.routeTask("module", "list_components", context_params_for_service, @conn)
      
      else # Case without module filter

        post_body = {
          :component_id => component_id,
          :subtype => 'template',
          :about   => about
        }

        case about
        when 'none'
          response = post rest_url("component/list")
        when 'nodes'
          response = post rest_url("component/list"), post_body
        else
          raise_validation_error_method_usage('list')
        end

        response.render_table(data_type) unless options.list?
      end

      return response
    end

    desc "COMPONENT-TEMPLATE-NAME/ID stage NODE-NAME/ID", "Stage indentified node for given component template."
    method_option :list, :type => :boolean, :default => false
    def stage(context_params)
      component_id, node_id = context_params.retrieve_arguments([:component_template_id!,:option_1!],method_argument_names)
      data_type = :component

      post_body = {
        :component_id => component_id
      }

      unless node_id.nil?
        post_body.merge!({:node_id => node_id})
      end
      
      response = post rest_url("component/stage"), post_body
      @@invalidate_map << :component_template

      response.render_table(data_type) unless options.list?
      response
    end



  end
end
