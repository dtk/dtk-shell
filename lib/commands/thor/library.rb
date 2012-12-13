module DTK::Client

  class Library < CommandBaseThor
    @@cached_response = {}

    def self.pretty_print_cols()
      PPColumns.get(:library)
    end

    def self.whoami()
      return :library, "library/list", nil
    end

    desc "[LIBRARY ID/NAME] info","Info for given library based on specified identifier."
    def info(library_id=nil)
      not_implemented
    end

    desc "[LIBRARY ID/NAME] list [nodes|components|assemblies]","Show nodes, components, or assemblies associated with library"
    # def show(arg1,arg2)
    def list(*rotated_args)
      if (rotated_args.size == 0)
        search_hash = SearchHash.new()
        search_hash.cols = pretty_print_cols()
        response = post rest_url("library/list"), search_hash.post_body_hash
        response.render_table(:library)
      else
        # library_id,about = [arg2,arg1]
        library_id,about = rotate_args(rotated_args)
        # sets data type to be used when printing table
        case about
         when "assemblies"
          data_type = :assembly_template
         when "nodes"
          data_type = :node_template
         when "components"
          data_type = :component
         else
          raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
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
    def import_service_module(service_modules, library_id=nil)
      post_body = {
       :remote_module_name => service_modules
      }
      post_body.merge!(:library_id => library_id) if library_id

      post rest_url("service_module/import"), post_body
    end

    desc "[LIBRARY ID/NAME] create-service-component SERVICE-MODULE-NAME", "Create an empty service module in library"
    def create(module_name,library_id=nil)
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
    def delete(component_module_id)
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

