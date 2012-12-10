module DTK::Client
  class Target < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:target)
    end

    def self.whoami()
      return :target, "target/list", nil
    end

    desc "create TARGET-NAME [DESCRIPTION]","Create new target"
    def create(target_id,description=nil)
      post_body = {
        :target_name => target_id,
        :description => description
      }
       post rest_url("target/create"), post_body
       # when changing context send request for getting latest targets instead of getting from cache
      @@invalidate_map = :target
    end

    desc "list","List targets."
    def list()
      response  = post rest_url("target/list")
      response.render_table(:target)
    end

    desc "TARGET-NAME/ID show [nodes|assemblies]","List nodes or assembly instances in given targets."
    def show(arg1,arg2)
      target_id,about = arg2,arg1
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
    
    desc "create-assembly SERVICE-MODULE-NAME ASSEMBLY-NAME", "Create assembly template from nodes in target" 
    def create_assembly(service_module_name,assembly_name)
      post_body = {
        :service_module_name => service_module_name,
        :assembly_name => assembly_name
      }
      post rest_url("target/create_assembly_template"), post_body
      # when changing context send request for getting latest assembly_templates instead of getting from cache
      @@invalidate_map = :assembly_template
    end

    desc "TARGET-NAME/ID converge", "Converges target instance"
    def converge(target_id)
      not_implemented()
    end
    
  end
end

