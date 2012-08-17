module DTK::Client
  class Library < CommandBaseThor
    def self.pretty_print_cols()
      [:display_name, :id, :description]
    end
    
    desc "list [type]","List libraries, or if type specified type those types in library"
    method_option :type,:aliases => "-t" ,:type => :string, :banner => "NODES|COMPONENTS|ASSEMBLIES", :desc => "List all libraries, and if passing options list all nodes/components/assemblies in that library." 
    def list()
      search_hash = SearchHash.new()
      search_hash.cols = pretty_print_cols()
      post rest_url("library/list"), search_hash.post_body_hash()
    end
  end
end

