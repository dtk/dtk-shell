module DTK::Client
  class ComponentTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:component)
    end

    def self.whoami()
      return :component_template, "component/list", {:subtype => 'template'}
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

    desc "[COMPONENT-TEMPLATE-NAME/ID] list [nodes]", "List all nodes for given component template."
    method_option :list, :type => :boolean, :default => false
    def list(context_params)
      component_id,about = context_params.retrieve_arguments([:component_template_id,:option_1],method_argument_names)
      about ||= 'none'
      data_type = :component


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
        raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
      end

      response.render_table(data_type) unless options.list?

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
