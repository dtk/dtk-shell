# TODO: Marked for removal [Haris]
module DTK::Client

  class Library < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:library)
    end

    def self.whoami()
      return :library, "library/list", nil
    end

    desc "[LIBRARY ID/NAME] info","Info for given library based on specified identifier."
    def info(context_params)
      library_id = context_params.retrieve_arguments([:library_id],method_argument_names)
      not_implemented
    end

    desc "LIBRARY ID/NAME list-nodes","Show nodes associated with library"
    def list_nodes(context_params)
      context_params.method_arguments = ["nodes"]
      list(context_params)
    end

    desc "LIBRARY ID/NAME list-components","Show components associated with library"
    def list_components(context_params)
      context_params.method_arguments = ["components"]
      list(context_params)
    end

    desc "LIBRARY ID/NAME list-assemblies","Show assemblies associated with library"
    def list_assemblies(context_params)
      context_params.method_arguments = ["assemblies"]
      list(context_params)
    end

    desc "list","Show nodes, components, or assemblies associated with library"
    def list(context_params)
      library_id, about = context_params.retrieve_arguments([:library_id, :option_1],method_argument_names||="")
      if library_id.nil?
        search_hash = SearchHash.new()
        search_hash.cols = pretty_print_cols()
        response = post rest_url("library/list"), search_hash.post_body_hash
        response.render_table(:library)
      else
        # sets data type to be used when printing table
        case about
         when "assemblies"
          data_type = :assembly_template
         when "nodes"
          data_type = :node_template
         when "components"
          data_type = :component
         else
          raise_validation_error_method_usage('list')
        end

        post_body = {
          :library_id => library_id,
          :about => about
        }
        response = post rest_url("library/info_about"), post_body
        response.render_table(data_type)
      end
    end

    desc "[LIBRARY ID/NAME] import-service-module REMOTE-SERVICE-MODULE[,...]", "Import remote service module into library"
    def import_service_module(context_params)
      library_id, service_modules = context_params.retrieve_arguments([:library_id, :option_1!],method_argument_names)
      post_body = {
        :remote_module_name => service_modules,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      }
      post_body.merge!(:library_id => library_id) if library_id

      post rest_url("service_module/import"), post_body
    end

    desc "[LIBRARY ID/NAME] create-service-component SERVICE-MODULE-NAME", "Create an empty service module in library"
    def create(context_params)
      library_id, module_name = context_params.retrieve_arguments([:library_id, :option_1!],method_argument_names)
      post_body = {
       :module_name => module_name
      }
      post_body.merge!(:library_id => library_id) if library_id
      response = post rest_url("service_module/create"), post_body
      # when changing context send request for getting latest libraries instead of getting from cache
      @@invalidate_map << :library

      return response
    end

    desc "[LIBRARY ID/NAME] delete-service-component COMPONENT-MODULE-NAME","Delete component module and all items contained in it"
    def delete(context_params)
      library_id, component_module_id = context_params.retrieve_arguments([:library_id, :option_1!],method_argument_names)
      post_body = {
       :component_module_id => component_module_id
      }
      post_body.merge!(:library_id => library_id) if library_id
      response = post rest_url("component_module/delete"), post_body
      # when changing context send request for getting latest libraries instead of getting from cache
      @@invalidate_map << :library

      return response
    end
  end
end

