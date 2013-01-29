module DTK::Client
  class Target < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:target)
    end

    def self.whoami()
      return :target, "target/list", nil
    end

    desc "create TARGET-NAME [DESCRIPTION]","Create new target"
    def create(context_params)
      target_name, description = context_params.retrieve_arguments([:option_1!,:option_2],method_argument_names)

      post_body = {
        :target_name => target_name,
        :description => description
      }
      response = post rest_url("target/create"), post_body
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
          raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
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

