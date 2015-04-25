module DTK::Client
  module CreateTargetMixin
    # option_list is of form [:provider!, :region, :keypair, :security_group!] indcating what is optional and what is required
    def create_target_aux(context_params,option_list)
      # we use :target_id but that will return provider_id (another name for target template ID)
      target_name = context_params.retrieve_arguments([:option_1],method_argument_names)
      provider, region, keypair, security_group = context_params.retrieve_thor_options(option_list, options)

      #TODO: data-driven check if legal provider type and then what options needed depending on provider type
      iaas_properties = Hash.new
      DTK::Shell::InteractiveWizard.validate_region(region) if region

      if security_group 
        security_groups = []
        raise ::DTK::Client::DtkValidationError.new("Multiple security groups should be separated with ',' and without spaces between them (e.g. --security_groups gr1,gr2,gr3,...) ") if security_group.end_with?(',')
        
        security_groups = security_group.split(',')
        iaas_properties.merge!(:keypair => keypair) if keypair
        
        if (security_groups.empty? || security_groups.size==1)
          iaas_properties.merge!(:security_group => security_group)
        else
          iaas_properties.merge!(:security_group_set => security_groups)
        end
      end

      post_body = {
        :provider_id => provider,
        :iaas_properties => iaas_properties
      }
      post_body.merge!(:target_name => target_name) if target_name
      post_body.merge!(:region => region) if region

      post rest_url("target/create"), post_body
    end
  end
end
