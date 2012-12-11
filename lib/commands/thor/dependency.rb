module DTK::Client
  class Dependency < CommandBaseThor
    desc "add-component COMPONENT-ID OTHER-COMPONENT-ID","Add before/require constraint"
    def add_component(component_id,other_component_id)
      post_body = {
        :component_id => component_id,
        :other_component_id => other_component_id,
        :type =>  "required by"
      }
      post rest_url("dependency/add_component_dependency"), post_body
      @@invalidate_map << :component_template
    end
  end
end

