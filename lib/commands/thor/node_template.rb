module DTK::Client
  class NodeTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:node)
    end

    def self.extended_context()
      {
        :context => {
          :add_component => "component_template"
        }
      }
    end

    def self.validation_list(context_params)
      get_cached_response(:node_template, "node/list", {:subtype => 'template'})
    end
=begin
  #Not implemented yet
    desc "NODE-TEMPLATE-NAME/ID info", "Get information about given node template."
    method_option :list, :type => :boolean, :default => false
    def info(context_params)
      node_template_id = context_params.retrieve_arguments([:node_template_id!],method_argument_names)
      data_type = :node

      post_body = {
        :node_id => node_template_id,
        :subtype => 'template'
      }
      response = post rest_url("node/info"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end
=end
#    desc "list --all -t [TARGET-NAME]", "List all node templates."
    desc "list", "List all node templates."
    method_option :all, :type => :boolean, :default => false
    method_option "target_identifier",:aliases => "-t" ,
      :type => :string, 
      :banner => "TARGET-IDENTIFIER",
      :desc => "Name or ID of desired target"
    def list(context_params)
      post_body = {
        :subtype => 'template',
        :target_indentifier => options.target_identifier,
        :is_list_all => options.all
      }
      response = post rest_url("node/list"), post_body
      response.render_table(options.all ? :node_template_all : :node_template)
    end

    #TODO: this may be moved to just be a utility fn
    desc "image-upgrade OLD-IMAGE-ID NEW-IMAGE-ID", "Upgrade use of OLD-IMAGE-ID to NEW-IMAGE-ID"
    def image_upgrade(context_params)
      old_image_id, new_image_id = context_params.retrieve_arguments([:option_1!, :option_2!],method_argument_names)
      post_body = {
        :old_image_id => old_image_id,
        :new_image_id => new_image_id
      }
      post rest_url("node/image_upgrade"), post_body
    end
=begin
    #TODO: move to form desc "NODE-TEMPLATE-NAME/ID stage [INSTANCE-NAME]"
    #will then have to reverse arguments
    desc "stage NODE-TEMPLATE-NAME [INSTANCE-NAME]", "Stage node template in target."
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create node instance in" 
    def stage(context_params)
      node_template_id, name = context_params.retrieve_arguments([:option_1!, :option_2],method_argument_names)
      post_body = {
        :node_template_identifier => node_template_id
      }
      post_body.merge!(:target_id => options["in-target"]) if options["in-target"]
      post_body.merge!(:name => name) if name
      response = post rest_url("node/stage"), post_body
      # when changing context send request for getting latest node_templates instead of getting from cache
      @@invalidate_map << :node_template
      @@invalidate_map << :node

      response
    end
=end
  end
end

