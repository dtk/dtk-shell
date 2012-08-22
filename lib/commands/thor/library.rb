module DTK::Client

  # Import subtasks are handled this way
  class ImportTask < CommandBaseThor
    namespace :import

    desc  "[LIBRARY-ID/LIBRARY-NAME] import-service-module REMOTE-SERVICE-MODULE[,...]", "Import remote service module into library"
    def service_module(service_modules, library_id=nil)
      post_body = {
       :remote_module_name => service_modules
      }
      post_body.merge!(:library_id => library_id) if library_id
      post rest_url("service_module/import"), post_body
    end

    def self.banner(task, namespace = true, subcommand = false)
      "#{basename} #{task.formatted_usage(self, true, subcommand)}"
    end
  end


  class Library < CommandBaseThor

    # TODO: Talk with Rich to see if we should use this since it has a bug
    # when using
    # Import sub tasking as mentioned above 
    # register(DTK::Client::ImportTask, 'import','import <command>','Import remote service/module module into library')

    def self.pretty_print_cols()
      PPColumns::LIBRARY
    end

    desc "[LIBRARY ID/NAME] info","Info for given library based on specified identifier."
    def info(library_id=nil)
      not_implemented
    end
    
    desc "[LIBRARY ID/NAME] list [TYPE]","List libraries, or if type specified type those types in library"
    def list(selected_type='none', library_id=nil)
      search_hash = SearchHash.new()
      search_hash.cols = pretty_print_cols()

        if library_id.nil?
        # there is no library id
        response = post rest_url("library/list"), search_hash.post_body_hash
      else
        # we include library id in search
        search_hash.filter = [:eq, ":library_library_id", library_id ]

        response = case selected_type
        when "nodes"
          search_hash.cols = PPColumns::NODE
          post rest_url("node/list"),search_hash.post_body_hash
        when "components"
          search_hash.cols = PPColumns::COMPONENT
          post rest_url("component/list"),search_hash.post_body_hash
        when "assemblies"
          # TODO: Filter libraries via assemblie is not working need to talk to Rich
          search_hash.cols = PPColumns::ASSEMBLY
          post rest_url("assembly/list_from_library"),search_hash.post_body_hash
        else
          raise DTK::Client::DtkError, "Not supported type '#{selected_type}' for given command."
        end
      end

      return response
    end

    desc "[LIBRARY ID/NAME] import-service-module REMOTE-SERVICE-MODULE[,...]", "Import remote service module into library"
    def import_service_module(service_modules, library_id=nil)
      post_body = {
       :remote_module_name => service_modules
      }
      post_body.merge!(:library_id => library_id) if library_id

      post rest_url("service_module/import"), post_body
    end

    desc "[LIBRARY ID/NAME] import-service-component REMOTE-SERVICE-COMPONENT[,...]", "Import remote service component into library"
    def import_service_component(service_components, library_id=nil)
      post_body = {
       :remote_module_name => service_components
      }
      post_body.merge!(:library_id => library_id) if library_id
      post rest_url("component_module/import"), post_body
    end

    desc "[LIBRARY ID/NAME] create-service-component SERVICE-MODULE-NAME", "Create an empty service module in library"
    def create(module_name,library_id=nil)
      post_body = {
       :module_name => module_name
      }
      post_body.merge!(:library_id => library_id) if library_id
      post rest_url("service_module/create"), post_body
    end

    desc "[LIBRARY ID/NAME] delete-service-component COMPONENT-MODULE-NAME","Delete component module and all items contained in it"
    def delete(component_module_id)
      post_body = {
       :component_module_id => component_module_id
      }
      post_body.merge!(:library_id => library_id) if library_id
      post rest_url("component_module/delete"), post_body
    end

  end
end

