module DTK::Client
  class Project < CommandBaseThor
    def self.pretty_print_cols()
      PPColumns::PROJECT
    end
    desc "list","List projects"
    def list()
      search_hash = SearchHash.new()
      search_hash.cols = pretty_print_cols()
      post rest_url("project/list"), search_hash.post_body_hash()
    end
  end
end

