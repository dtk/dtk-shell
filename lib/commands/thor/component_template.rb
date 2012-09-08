module DTK::Client
  class ComponentTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns::COMPONENT
    end

    desc "COMPONENT-NAME/ID info", "Get information about given component template."
    method_option :list, :type => :boolean, :default => false
    def info(component_id=nil)
      data_type = DataType::COMPONENT

      post_body = {
        :component_id => component_id,
        :subtype => 'template'
      }
      response = post rest_url("component/info"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "COMPONENT-NAME/ID list nodes", "List all nodes for given component template."
    method_option :list, :type => :boolean, :default => false
    def list(nodes='none', component_id=nil)
      data_type = DataType::COMPONENT

      post_body = {
        :component_id => component_id,
        :subtype => 'template',
        :about   => nodes
      }

      case nodes
      when 'none'
        response = post rest_url("component/list")
      when 'nodes'
        response = post rest_url("component/list"), post_body
      else
        raise DTK::Client::DtkError, "Not supported type '#{nodes}' for given command."
      end

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "COMPONENT-NAME/ID stage NODE-NAME/ID", "Stage indentified node for given component template."
    method_option :list, :type => :boolean, :default => false
    def stage(node_id, component_id=nil)
      data_type = DataType::COMPONENT

      post_body = {
        :component_id => component_id
      }

      unless node_id.nil?
        post_body.merge!({:node_id => node_id})
      end
      
      response = post rest_url("component/stage"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

  end
end
