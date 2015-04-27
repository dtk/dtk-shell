module DTK::Client
  class Provider < CommandBaseThor

    def self.valid_children()
      [:target]
    end

    def self.all_children()
      [:target]
    end

    def self.validation_list(context_params)
      get_cached_response(:provider, "target/list", {:subtype => :template })
    end

    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :command_only => {
          :target => [
            ['delete-target',"delete-target TARGET-IDENTIFIER","# Deletes target"],
            ['list',"list","# Lists available targets."]

          ]
        },
        :identifier_only => {
          :target      => [
            ['list-nodes',"list-nodes","# Lists node instances in given targets."],
            ['list-services',"list-services","# Lists assembly instances in given targets."]
          ]
        }
      })
    end

    def self.valid_child?(name_of_sub_context)
      Provider.valid_children().include?(name_of_sub_context.to_sym)
    end

    desc "create-provider-ec2 PROVIDER-NAME [--keypair KEYPAIR] [--security-group SECURITY-GROUP(S)]", "Create provider for ec2 vpc or classic. Multiple security groups separated with ',' (gr1,gr2,gr3,...)"
    method_option :keypair, :type => :string
    method_option :security_group, :type => :string, :aliases => '--security-groups'
    # TODO: made this a hidden option; needs to be updated because now choice if vpc or classic
    method_option :bootstrap, :type => :boolean, :default => false
    def create_provider_ec2(context_params)
      provider_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      provider_type = 'ec2'

      iaas_properties = Hash.new

      keypair, security_group = context_params.retrieve_thor_options([:keypair, :security_group], options)

      iaas_properties.merge!(:keypair_name => keypair) if keypair
      if security_group
        if security_group.end_with?(',')
          raise ::DTK::Client::DtkValidationError.new("Multiple security groups should be separated with ',' and without spaces between them (e.g. --security_groups gr1,gr2,gr3,...) ")
        end

        security_groups = security_group.split(',')

        if (security_groups.empty? || security_groups.size==1)
          iaas_properties.merge!(:security_group => security_group)
        else
          iaas_properties.merge!(:security_group_set => security_groups)
        end
      end

      result = DTK::Shell::InteractiveWizard::interactive_user_input(
        {'IAAS Credentials' => { :type => :group, :options => [
              {:key    => {}},
              {:secret => {}}
          ]}})
      access_key, secret_key = result['IAAS Credentials'].values_at(:key, :secret)
      iaas_properties.merge!(:key => access_key,:secret => secret_key)

      # Remove sensitive readline history
      OsUtil.pop_readline_history(2)

      post_body =  {
        :iaas_properties => iaas_properties,
        :provider_name   => provider_name,
        :iaas_type       => 'ec2',
        :no_bootstrap    => ! options.bootstrap?
      }

      response = post rest_url("target/create_provider"), post_body
      @@invalidate_map << :provider

      response
    end

    desc "create-provider-physical PROVIDER-NAME", "Create provider to manage physical nodes."
    def create_provider_physical(context_params)
      provider_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      # Remove sensitive readline history
      OsUtil.pop_readline_history(2)

      post_body =  {
        :provider_name => provider_name,
        :iaas_type => 'physical'
      }

      response = post rest_url("target/create_provider"), post_body
      @@invalidate_map << :provider

      response
    end

=begin
TODO: deprecated until this can be in sync with create-targets from target context where params depend on type

    desc "PROVIDER-ID/NAME create-target [TARGET-NAME] --region REGION --keypair KEYPAIR --security-group SECURITY-GROUP(S)", "Create target based on given provider"
    method_option :region, :type => :string
    method_option :keypair, :type => :string
    method_option :security_group, :type => :string, :aliases => '--security-groups'
    def create_target(context_params)
      # we use :target_id but that will retunr provider_id (another name for target template ID)
      provider_id, target_name = context_params.retrieve_arguments([:provider_id!, :option_1],method_argument_names)
      region, keypair, security_group = context_params.retrieve_thor_options([:region!, :keypair!, :security_group!], options)

      #TODO: data-driven check if legal provider type and then what options needed depending on provider type
      iaas_properties = Hash.new
      DTK::Shell::InteractiveWizard.validate_region(region)

      security_groups = []
      raise ::DTK::Client::DtkValidationError.new("Multiple security groups should be separated with ',' and without spaces between them (e.g. --security_groups gr1,gr2,gr3,...) ") if security_group.end_with?(',')

      security_groups = security_group.split(',')
      iaas_properties.merge!(:keypair => keypair)

      if (security_groups.empty? || security_groups.size==1)
        iaas_properties.merge!(:security_group => security_group)
      else
        iaas_properties.merge!(:security_group_set => security_groups)
      end

      post_body = {
        :provider_id => provider_id,
        :region => region,
        :iaas_properties => iaas_properties
      }
      post_body.merge!(:target_name => target_name) if target_name
      response = post rest_url("target/create"), post_body
      @@invalidate_map << :target

      response
    end
=end

    desc "list","Lists available providers."
    def list(context_params)
      if context_params.is_there_command?(:"target")
        list_targets(context_params)
      else
        response  = post rest_url("target/list"), { :subtype => :template }
        response.render_table(:provider)
      end
    end

    #TODO: Aldin; wanted to name this list_targets, but did not know how to do so w/o conflicting with desc "PROVIDER-ID/NAME list-targets
    # Aldin: moved this to target base context (target>list)
    #
    # desc "list-all-targets","Lists all targets for all providers."
    # def list_all_targets(context_params)
    #   response  = post rest_url("target/list"), { :subtype => :instance }
    #   response.render_table(:target)
    # end

    desc "PROVIDER-ID/NAME list-targets", "List targets"
    def list_targets(context_params)
      provider_id = context_params.retrieve_arguments([:provider_id!],method_argument_names)

      response = post rest_url("target/list"), { :subtype => :instance, :parent_id => provider_id }
      response.render_table(:target)
    end

    desc "delete-provider PROVIDER-IDENTIFIER","Deletes target provider, its targets, and their assemblies"
    def delete_provider(context_params)
      provider_id   = context_params.retrieve_arguments([:option_1!],method_argument_names)

      # require explicit acknowldegement since deletes all targtes under it
      return unless Console.confirmation_prompt("Are you sure you want to delete provider with identifier '#{provider_id}' and all target and service isntances under it" +'?')
      
      post_body = {
        :provider_id => provider_id
      }

      @@invalidate_map << :provider

      post rest_url("target/delete_provider"), post_body
    end

    no_tasks do
      
      def decompose_provider_type_and_name(composed_name)
        provider_type, provider_name = composed_name.split(':')

        if (provider_type.nil? || provider_name.nil? || provider_type.empty? || provider_name.empty?)
          raise ::DTK::Client::DtkValidationError.new("Provider name and type are required parameters and should be provided in format PROVIDER-TYPE:PROVIDER-NAME")
        end

        return [provider_type, provider_name]
      end

    end
    

  end
end
