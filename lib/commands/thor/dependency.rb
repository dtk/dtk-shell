module DTK::Client
  class Dependency < CommandBaseThor
    desc "create-component COMPONENT-ID OTHER-COMPONENT-ID","Add before/require constraint"
    def create_component(context_params)
      component_id, other_component_id = context_params.retrieve_arguments([:option_1!,:option_2!],method_argument_names)
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

