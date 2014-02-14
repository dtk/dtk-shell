module DTK::Client
  class Provider < CommandBaseThor

    def self.whoami()
      return :provider, "target/list", { :subtype => :template }
    end

    def self.valid_children()
      [:target]
    end

    def self.all_children()
      [:target]
    end

    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :command_only => {
          :target => [
            ['delete-target',"delete-target TARGET-IDENTIFIER","# Deletes target"],
            ['list-targets',"list-targets","# Lists available targets."]

          ]
        },
        :identifier_only => {
          :target      => [
            ['list-nodes',"list-nodes","# Lists node instances in given targets."],
            ['list-assemblies',"list-assemblies","# Lists assembly instances in given targets."]
          ]
        }
      })
    end

    def self.valid_child?(name_of_sub_context)
      return Provider.valid_children().include?(name_of_sub_context.to_sym)
    end

    desc "create-provider PROVIDER-TYPE:PROVIDER-NAME --access-key ACCESS_KEY --secret-key SECRET_KEY --keypair KEYPAIR --security-group SECURITY-GROUP [--no-bootstrap]", "Create provider"
    method_option :keypair,    :type => :string
    method_option :access_key, :type => :string
    method_option :secret_key, :type => :string
    method_option :security_group, :type => :string
    method_option :no_bootstrap, :type => :boolean, :default => false
    def create_provider(context_params)
      composed_provider_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      provider_type, provider_name = decompose_provider_type_and_name(composed_provider_name)
      access_key, secret_key, keypair, security_group = context_params.retrieve_thor_options([:access_key!, :secret_key!, :keypair!, :security_group!], options)

      post_body = {
        :iaas_properties => {
          :key     => access_key,
          :secret  => secret_key,
          :keypair_name => keypair,
          :security_group => security_group
        },
          :target_name => provider_name,
          :iaas_type => provider_type.downcase,
          :no_bootstrap => options.no_bootstrap?
      }

      response = post rest_url("target/create"), post_body
      @@invalidate_map << :provider

      return response
    end


    desc "PROVIDER-ID/NAME create-target --region REGION", "Create target based on given provider"
    method_option :region, :type => :string
    def create_target(context_params)
      # we use :target_id but that will retunr provider_id (another name for target template ID)
      composed_provider_id, composed_provider_name = context_params.retrieve_arguments([:provider_id!,:provider_name!],method_argument_names)
      region = context_params.retrieve_thor_options([:region!], options)

      DTK::Shell::InteractiveWizard.validate_region(region)

      post_body = {
        # take only last part of the name, e.g. provider::DemoABH
        :target_name => composed_provider_name,
        :target_template_id => composed_provider_id,
        :region => region
      }

      response = post rest_url("target/create"), post_body
      @@invalidate_map << :target

      return response
    end


    desc "list","Lists available providers."
    def list(context_params)
      response  = post rest_url("target/list"), { :subtype => :template }
      response.render_table(:provider)
    end

    #TODO: Aldin; wanted to name this list_targets, but did not know how to do so w/o conflicting with desc "PROVIDER-ID/NAME list-targets
    desc "list-all-targets","Lists all targets for all providers."
    def list_all_targets(context_params)
      response  = post rest_url("target/list"), { :subtype => :instance }
      response.render_table(:target)
    end

    desc "PROVIDER-ID/NAME list-targets", "List targets"
    def list_targets(context_params)
      provider_id = context_params.retrieve_arguments([:provider_id!],method_argument_names)

      response  = post rest_url("target/list"), { :subtype => :instance, :parent_id => provider_id }

      response.render_table(:target)
    end

    desc "delete-provider PROVIDER-IDENTIFIER [-y]","Deletes targets provider"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_provider(context_params)
      provider_id   = context_params.retrieve_arguments([:option_1!],method_argument_names)

      unless options.force?
        return unless Console.confirmation_prompt("Are you sure you want to delete provider with identifier '#{provider_id}'"+'?')
      end
      
      # this goes to provider
      # Console.confirmation_prompt("Are you sure you want to delete target '#{target_id}' (all assemblies that belong to this target will be deleted as well)'"+'?')
      
      post_body = {
        :target_id => provider_id
      }

      @@invalidate_map << :provider

      return post rest_url("target/delete"), post_body
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
