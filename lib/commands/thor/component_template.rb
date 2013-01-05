module DTK::Client
  class ComponentTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:component)
    end

    def self.whoami()
      return :component_template, "component/list", {:subtype => 'template'}
    end

    desc "COMPONENT-TEMPLATE-NAME/ID list", "List component templates"
    def list()
      data_type = :component
      response = post rest_url("component/list")
      response.render_table(:component)
    end
  end
end

