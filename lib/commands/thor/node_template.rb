module DTK::Client
  class NodeTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns::NODE
    end

    desc "NODE-NAME/ID info", "Get information about given node template."
    method_option :list, :type => :boolean, :default => false
    def info(node_id=nil)
      data_type = DataType::NODE

      post_body = {
        :node_id => node_id,
        :subtype => 'template'
      }
      response = post rest_url("node/info"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "NODE-NAME/ID list targets", "List all components for given node template."
    method_option :list, :type => :boolean, :default => false
    def list(targets='none', node_id=nil)
      data_type = DataType::NODE

      post_body = {
        :node_id => node_id,
        :subtype => 'template',
        :about   => targets
      }

      case targets
      when 'none'
        response = post rest_url("node/list")
      when 'targets'
        response = post rest_url("node/list"), post_body
      else
        raise DTK::Client::DtkError, "Not supported type '#{targets}' for given command."
      end

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "NODE-NAME/ID stage TARGET-NAME/ID", "Stage indentified target for given node template."
    method_option :list, :type => :boolean, :default => false
    def stage(target_id, node_id=nil)
      data_type = DataType::NODE

      post_body = {
        :node_id => node_id
      }

      unless target_id.nil?
        post_body.merge!({:target_id => target_id})
      end
      
      response = post rest_url("node/stage"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

  end
end

