dtk_require('common_base')
module DTK; module Client; module Commands::Common
  class CreateTarget < Base
    # option_list is of form [:provider!, :region, :keypair, :security_group!] indcating what is optional and what is required
    def execute(type,option_list)
      # we use :target_id but that will return provider_id (another name for target template ID)
      target_name = retrieve_arguments([:option_1])
      iaas_properties = iaas_properties(type,option_list)
      provider = iaas_properties.delete(:provider)
      post_body = {
        :type             => type.to_s,
        :provider_id      => provider,
        :iaas_properties  => iaas_properties
      }
      post_body.merge!(:target_name => target_name) if target_name
      post 'target/create', post_body
    end

   private
    def iaas_properties(type,option_list)
pp option_list
      provider, region, keypair, security_group = retrieve_thor_options(option_list)
      iaas_properties = Hash.new
iaas_properties.merge!(:provider => provider) if provider

      Shell::InteractiveWizard.validate_region(region) if region
      iaas_properties.merge!(:keypair => keypair) if keypair
      
      if security_group 
        security_groups = []
        raise DtkValidationError.new("Multiple security groups should be separated with ',' and without spaces between them (e.g. --security_groups gr1,gr2,gr3,...) ") if security_group.end_with?(',')
        
        security_groups = security_group.split(',')
        
        if (security_groups.empty? || security_groups.size==1)
          iaas_properties.merge!(:security_group => security_group)
        else
          iaas_properties.merge!(:security_group_set => security_groups)
        end
      end
      iaas_properties
    end
  end
end; end; end
