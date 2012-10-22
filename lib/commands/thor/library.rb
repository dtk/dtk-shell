module DTK::Client

  class Library < CommandBaseThor
    @@cached_response = {}

    def self.pretty_print_cols()
      PPColumns.get(:library)
    end

    desc "[LIBRARY ID/NAME] info","Info for given library based on specified identifier."
    def info(library_id=nil)
      not_implemented
    end
    
    desc "[LIBRARY ID/NAME] list [nodes|components|assemblies]","List libraries, or if type specified type those types in library, possible values nodes, components, assemblies"
    method_option :list, :type => :boolean, :default => false
    def list(selected_type='none', library_id=nil)
      # sets data type to be used when printing table
      data_type = :library

      search_hash = SearchHash.new()
      search_hash.cols = pretty_print_cols()

        if library_id.nil?
        # there is no library id
        response = post rest_url("library/list"), search_hash.post_body_hash
      else
        # we include library id in search
        search_hash.filter = [:eq, ":library_library_id", library_id ]

        response = case selected_type.downcase
        when "nodes"
          search_hash.cols,data_type = PPColumns.get(:node), :node
          response = post rest_url("node/list"),search_hash.post_body_hash
        when "components"
          search_hash.cols, data_type = PPColumns.get(:component), :component
          post rest_url("component/list"),search_hash.post_body_hash
        when "assemblies"
          # TODO: Filter libraries via assemblie is not working need to talk to Rich
          search_hash.cols, data_type = PPColumns.get(:assembly), :assembly
          post rest_url("assembly/list_from_library"),search_hash.post_body_hash
        else
          raise DTK::Client::DtkError, "Not supported type '#{selected_type}' for given command."
        end
      end

      # sets table render
      response.render_table(data_type) unless options.list?

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

    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:library, "library/list")

        unless (response.nil? || response.empty?)
          unless response['data'].nil?
            response['data'].each do |element|
              return true if (element['id'].to_s==value || element['display_name'].to_s==value)
            end
          end      
        end
        # if response is ok but response['data'] is nil, display warning message
        DtkLogger.instance.warn("Response data is nil, please check if your request is valid.")
        return false
      end

      def self.get_identifiers(conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:library, "library/list")

        unless (response.nil? || response.empty?)
          unless response['data'].nil?
            identifiers = []
            response['data'].each do |element|
               identifiers << element['display_name']
            end
            return identifiers
          end

        end
        # if response is ok but response['data'] is nil, display warning message
        DtkLogger.instance.warn("Response data is nil, please check if your request is valid.")
        return []
      end
    end

  end
end

