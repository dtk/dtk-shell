module DTK::Client
  class Target < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:target)
    end

    def self.alternate_identifiers()
      return ['PROVIDER']
    end

    desc "TARGET-NAME/ID list-nodes","Lists node instances in given targets."
    def list_nodes(context_params)
      context_params.method_arguments = ["nodes"]
      list_targets(context_params)
    end

    desc "TARGET-NAME/ID list-assemblies","Lists assembly instances in given targets."
    def list_assemblies(context_params)
      context_params.method_arguments = ["assemblies"]
      list_targets(context_params)
    end


    def self.validation_list(context_params)
      provider_id = context_params.retrieve_arguments([:provider_id])

      if provider_id
        # if assembly_id is present we're loading nodes filtered by assembly_id
        post_body = {
          :subtype   => :instance,
          :parent_id => provider_id
        }

        response = get_cached_response(:provider_target, "target/list", post_body)
      else
        # otherwise, load all nodes
        response = get_cached_response(:target, "target/list", { :subtype => :instance })
      end

      return response
    end

=begin
    desc "list-providers","Lists available providers."
    def list_providers(context_params)
      context_params.method_arguments = ["templates"]
      list_targets(context_params)
    end
=end

    desc "list-targets","Lists available targets."
    def list_targets(context_params)
      provider_id, target_id, about = context_params.retrieve_arguments([:provider_id, :target_id, :option_1],method_argument_names||="")

      if target_id.nil?
        post_body = { 
          :subtype   => :instance,
          :parent_id => provider_id
        }
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

    desc "delete-target TARGET-IDENTIFIER","Deletes target or provider"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_target(context_params)
      target_id   = context_params.retrieve_arguments([:option_1!],method_argument_names)

      # No -y options since risk is too great
      return unless Console.confirmation_prompt("Are you sure you want to delete target '#{target_id}' (all assemblies/nodes that belong to this target will be deleted as well)'"+'?')
     
      post_body = {
        :target_id => target_id
      }

      @@invalidate_map << :target

      return post rest_url("target/delete"), post_body
    end

=begin
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
=end


  end
end
