module DTK::Client
  class Target < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:target)
    end

    def self.whoami()
      return :target, "target/full_list", nil
    end

    def self.alternate_identifiers()
      return ['PROVIDER']
    end


    #def self.validation_list(context_params)
    #  get_cached_response(:target, "target/list", { :subtype => :template }).data
    #end

    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :command_only => {
          :self => [
            ["list"," list","# List targets."],
            ["list-templates"," list-templates","# List target templates."]
          ]
        },
        :identifier_only => {
          :self      => [
            ["list-nodes","list-nodes","# List node instances in given targets."],
            ["list-assemblies","list-assemblies","# List assembly instances in given targets."]
          ]
        },
        :identifier_provider => {
          :self      => [
            ["create-target","create-target","# WORKSS!!!!!!!!!!!!!."]
          ]
        }
      })
    end

    desc "create-provider PROVIDER-TYPE:PROVIDER-NAME --access-key ACCESS_KEY --secret-key SECRET_KEY --keypair KEYPAIR [--no-bootstrap]", "Create target template"
    method_option :keypair,    :type => :string
    method_option :access_key, :type => :string
    method_option :secret_key, :type => :string
    method_option :no_bootstrap, :type => :boolean, :default => false
    def create_provider(context_params)
      composed_provider_name = context_params.retrieve_arguments([:option_1!],method_argument_names)

      provider_type, provider_name = decompose_provider_type_and_name(composed_provider_name)
      access_key, secret_key, keypair = context_params.retrieve_thor_options([:access_key!, :secret_key!, :keypair!], options)

      post_body = {
        :iaas_properties => {
          :key     => access_key,
          :secret  => secret_key,
          :keypair_name => keypair
        },
          :target_name => provider_name,
          :iaas_type => provider_type.downcase,
          :no_bootstrap => options.no_bootstrap?
      }

      response = post rest_url("target/create"), post_body
      @@invalidate_map << :target

      return response
    end


    desc "PROVIDER-ID/NAME create-target --region REGION", "Create target"
    method_option :region, :type => :string
    def create_target(context_params)
      # we use :target_id but that will retunr provider_id (another name for target template ID)
      composed_provider_id, composed_provider_name = context_params.retrieve_arguments([:target_id!,:target_name!],method_argument_names)
      region = context_params.retrieve_thor_options([:region!], options)

      DTK::Shell::InteractiveWizard.validate_region(region)

      post_body = {
        # take only last part of the name, e.g. provider::DemoABH
        :target_name => composed_provider_name.split('::').last,
        :target_template_id => composed_provider_id,
        :region => region
      }

      # DEBUG SNIPPET >>>> REMOVE <<<<
      require 'ap'
      ap post_body

      response = post rest_url("target/create"), post_body
      @@invalidate_map << :target

      return response
    end

    desc "create","Wizard that will guide you trough creation of target and target-template"
    def create(context_params)
      
      # we get existing templates
      target_templates = post rest_url("target/list"), { :subtype => :template }

      # ask user to select target template
      wizard_params = [{:target_template => { :type => :selection, :options => target_templates['data'], :display_field => 'display_name', :skip_option => true }}]
      target_template_selected = DTK::Shell::InteractiveWizard.interactive_user_input(wizard_params)
      target_template_id = (target_template_selected[:target_template]||{})['id']

      wizard_params = [
        {:target_name     => {}},
        {:description      => {:optional => true }}
      ]

      if target_template_id.nil?
        # in case user has not selected template id we will needed information to create target
        wizard_params.concat([
          {:iaas_type       => { :type => :selection, :options => [:ec2] }},
          {:aws_install     => { :type => :question, 
                                 :question => "Do we have your permission to add necessery 'key-pair' and 'security-group' to your EC2 account?", 
                                 :options => ["yes","no"], 
                                 :required_options => ["yes"],
                                 :explanation => "This permission is necessary for creation of a custom target."
                                }},
          {:iaas_properties => { :type => :group, :options => [
              {:key    => {}},
              {:secret => {}},
              {:region => {:type => :selection, :options => DTK::Shell::InteractiveWizard::EC2_REGIONS}},
          ]}},
        ])
      end

      post_body = DTK::Shell::InteractiveWizard.interactive_user_input(wizard_params)
      post_body ||= {}

      # this means that user has not given permission so we skip request
      return unless (target_template_id || post_body[:aws_install])

      # in case user chose target ID
      post_body.merge!(:target_template_id => target_template_id) if target_template_id


      response = post rest_url("target/create"), post_body
       # when changing context send request for getting latest targets instead of getting from cache
      @@invalidate_map << :target

      return response
    end

    desc "TARGET-NAME/ID list-nodes","List node instances in given targets or target templates."
    def list_nodes(context_params)
      context_params.method_arguments = ["nodes"]
      list(context_params)
    end

    desc "TARGET-NAME/ID list-assemblies","List assembly instances in given targets or target templates."
    def list_assemblies(context_params)
      context_params.method_arguments = ["assemblies"]
      list(context_params)
    end

    desc "list-templates","List target templates."
    def list_templates(context_params)
      context_params.method_arguments = ["templates"]
      list(context_params)
    end

    desc "list","List targets."
    def list(context_params)
      target_id, about = context_params.retrieve_arguments([:target_id, :option_1],method_argument_names||="")
      if target_id.nil?
        post_body = (about||'').include?("template") ?  { :subtype => :template } : {}
        response  = post rest_url("target/list"), post_body
           
        response.render_table(:target)
      else
        post_body = {
          :target_id => target_id,
          :about => about
        }

        case about
          when "nodes"
          response  = post rest_url("target/info_about"), post_body
          data_type =  :node
          when "assemblies"
          response  = post rest_url("target/info_about"), post_body
          data_type =  :assembly
         else
          raise_validation_error_method_usage('list')
        end

        response.render_table(data_type)
      end
    end

    desc "delete TARGET-IDENTIFIER","Deletes target or target template"
    def delete(context_params)
      target_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      post_body = {
        :target_id => target_id
      }

      return post rest_url("target/delete"), post_body
    end
    
    desc "create-assembly SERVICE-MODULE-NAME ASSEMBLY-NAME", "Create assembly template from nodes in target" 
    def create_assembly(context_params)
      service_module_name, assembly_name = context_params.retrieve_arguments([:option_1!, :option_2!],method_argument_names)
      post_body = {
        :service_module_name => service_module_name,
        :assembly_name => assembly_name
      }
      response = post rest_url("target/create_assembly_template"), post_body
      # when changing context send request for getting latest assembly_templates instead of getting from cache
      @@invalidate_map << :assembly_template

      return response
    end

    desc "TARGET-NAME/ID converge", "Converges target instance"
    def converge(context_params)
      not_implemented()
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
