module DTK::Client
  class ComponentTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:component)
    end

    def self.whoami()
      return :component_template, "component/list", {:subtype => 'template'}
    end

    desc "COMPONENT-TEMPLATE-NAME/ID list [-s SERVICE-NAME]", "List component templates"
    method_option "service",:aliases => "-s" ,
    :type => :string, 
    :banner => "SERVICE",
    :desc => "Service to filter component templates by"

    def list()
      post_body = Hash.new
      post_body.merge!(:context => "service_module/#{options['service']}") if options['service']
      response = post rest_url("component/list"), post_body
      response.render_table(:component)
    end
  end
end

