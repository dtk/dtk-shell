module DTK::Client
  class Target < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:target)
    end

    def self.whoami()
      return :target, "target/list", nil
    end

    desc "create","Wizard that will guide you trough creation of target and target-template"
    def create(context_params)
      
      # we get existing templates
      target_templates = post rest_url("target/list"), { :subtype => :template }
      
      # we get names and descriptions for given list
      selection_names = target_templates['data'].map { |tt| "#{tt['display_name']}" }
      selection_names << (skip_template = "I do not want to use template.".colorize(:yellow))

      # ask user to select target template
      wizard_params = [{:target_template => { :type => :selection, :options => selection_names, :display_field => 'display_name' }}]
      target_template_selected = DTK::Shell::InteractiveWizard.interactive_user_input(wizard_params)
      target_template_id = target_template_selected['id']

      wizard_params = [
        {:target_name     => {}},
        {:description      => {:optional => true }}
      ]

      if target_template_id.nil?
        # in case user has not selected template id we will needed information to create target
        wizard_params.concact([
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
              {:region => {}},
          ]}},
        ])
      end

      post_body = DTK::Shell::InteractiveWizard.interactive_user_input(wizard_params)

      # this means that user has not given permission so we skip request
      return unless post_body[:aws_install]



      response = post rest_url("target/create"), post_body.merge(:target_template_id => target_template_id)
       # when changing context send request for getting latest targets instead of getting from cache
      @@invalidate_map << :target

      return response
    end

    desc "[TARGET-NAME/ID] list [nodes|assemblies]","List nodes or assembly instances in given targets."
    def list(context_params)
      target_id, about = context_params.retrieve_arguments([:target_id, :option_1],method_argument_names)
      if target_id.nil?
        response  = post rest_url("target/list")
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
    
  end
end

