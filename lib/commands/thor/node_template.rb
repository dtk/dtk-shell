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

    #TODO: move to form desc "NODE-TEMPLATE-NAME/ID stage [INSTANCE-NAME]"
    #will then have to reverse arguments
    desc "stage NODE-TEMPLATE-ID [INSTANCE-NAME]", "Stage node template in target."
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create assembly in" 
    def stage(node_template_id,name=nil)
      post_body = {
        :node_template_id => node_template_id
      }
      post_body.merge!(:target_id => options["in-target"]) if options["in-target"]
      post_body.merge!(:name => name) if name
      post rest_url("node/stage"), post_body
    end
  end
end

