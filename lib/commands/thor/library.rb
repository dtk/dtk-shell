module DTK::Client
  class Library < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns::LIBRARY
    end
    
    desc "[LIBRARY-ID/LIBRARY-NAME] list [type]","List libraries, or if type specified type those types in library"
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
  end
end

