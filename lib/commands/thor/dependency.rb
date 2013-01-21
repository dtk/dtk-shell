module DTK::Client
  class Dependency < CommandBaseThor
    desc "add-component COMPONENT-ID OTHER-COMPONENT-ID","Add before/require constraint"
    def add_component(hashed_args)
      component_id, other_component_id = CommandBaseThor.retrieve_arguments([:option_1, :option_2],hashed_args)
      post_body = {
        :component_id => component_id,
        :other_component_id => other_component_id,
        :type =>  "required by"
      }
      response = post rest_url("dependency/add_component_dependency"), post_body
      @@invalidate_map << :component_template

      return response
    end
  end
end

