module DTK::Client
  class Target < CommandBaseThor
    def self.pretty_print_cols()
      PPColumns::TARGET
    end
    desc "list","List targets"
    method_option :list, :type => :boolean, :default => false
    def list()
      search_hash = SearchHash.new()
      search_hash.cols = pretty_print_cols()
      response = post rest_url("target/list"), search_hash.post_body_hash()

      response.render_table(DataType::TARGET) unless options.list?
      return response
    end
    
    desc "create-assembly SERVICE-MODULE-NAME ASSEMBLY-NAME", "Create assembly template from nodes in target" 
    def create_assembly(service_module_name,assembly_name)
      post_body = {
        :service_module_name => service_module_name,
        :assembly_name => assembly_name
      }
      post rest_url("target/create_assembly_template"), post_body
    end
  end
end

