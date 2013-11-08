module DTK; module Client; class CommandHelper
  class ServiceLink < self; class << self
    def post_body_with_id_keys(context_params,method_argument_names)
      assembly_or_workspace_id = context_params.retrieve_arguments([[:assembly_id!,:workspace_id!]])
      ret = {:assembly_id => assembly_or_workspace_id}
      if context_params.is_last_command_eql_to?(:component)
        component_id,service_type = context_params.retrieve_arguments([:component_id!,:option_1!],method_argument_names)
        ret.merge(:input_component_id => component_id,:service_type => service_type)
      else
        service_link_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
        ret.merge(:service_link_id => service_link_id)
      end
    end

  end; end
end; end; end


