module DTK::Client
  class Library < CommandBaseThor
    def self.pretty_print_cols()
      [:display_name, :id, :description]
    end
    
    desc "[LIBRARY-ID/LIBRARY-NAME] list [type]","List libraries, or if type specified type those types in library"
    def list(selected_type='none', library_id=nil)
      search_hash = SearchHash.new()
      search_hash.cols = pretty_print_cols()

      # TODO: Pretty print collumns need to be group into static method to hold them as constants.
      # problem is when searching library, node, components, assemblies we will not have the same columns.

      if library_id.nil?
        # there is no library id
        response = post rest_url("library/list"), search_hash.post_body_hash
      else
        # we include library id in search
        search_hash.filter = [:eq, ":library_library_id", library_id ]

        response = case selected_type
        when "nodes"
          post rest_url("node/list"),search_hash.post_body_hash
        when "components"
          post rest_url("component/list"),search_hash.post_body_hash
        when "assemblies"
          # TODO: Filter libraries via assemblie is not working need to talk to Rich
          post rest_url("assembly/list_from_library"),search_hash.post_body_hash
        else
          raise DTK::Client::DtkError, "Not supported type '#{selected_type}' for given command."
        end
      end

      return response
    end
  end
end

