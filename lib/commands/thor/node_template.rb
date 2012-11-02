module DTK::Client
  class NodeTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:node)
    end

    def self.whoami()
      return :node_template, "node/list", {:subtype => 'template'}
    end

    desc "NODE-NAME/ID info", "Get information about given node template."
    method_option :list, :type => :boolean, :default => false
    def info(node_id=nil)
      data_type = :node

      post_body = {
        :node_id => node_id,
        :subtype => 'template'
      }
      response = post rest_url("node/info"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "list", "List all node templates."
    def list()
      post_body = {
        :subtype => 'template'
      }
      response = post rest_url("node/list"), post_body
      response.render_table(:node_template)
    end

    #TODO: this may be moved to just be a utility fn
    desc "image-upgrade OLD-IMAGE-ID NEW-IMAGE-ID", "Upgrade use of OLD-IMAGE-ID to NEW-IMAGE-ID"
    def image_upgrade(old_image_id,new_image_id)
      post_body = {
        :old_image_id => old_image_id,
        :new_image_id => new_image_id
      }
      post rest_url("node/image_upgrade"), post_body
    end

    desc "NODE-NAME/ID stage TARGET-NAME/ID", "Stage indentified target for given node template."
    method_option :list, :type => :boolean, :default => false
    def stage(target_id, node_id=nil)
      data_type = :node

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

