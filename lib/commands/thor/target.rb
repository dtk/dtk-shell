module DTK::Client
  class Target < CommandBaseThor
    def self.pretty_print_cols()
      PPColumns::TARGET
    end

    desc "[TARGET-NAME/ID] list [nodes|assemblies]","List targets or nodes in given targets."
    method_option :list, :type => :boolean, :default => false
    def list(about="none",target_id=nil)

      post_body = {
        :target_id => target_id,
        :assembly_name => about
      }

      case about
      when "none"
        response  = post rest_url("target/list")
        data_type =  DataType::TARGET
      when "nodes"
        response  = post rest_url("target/list"), post_body
        data_type =  DataType::NODE
      when "assemblies"
        response  = post rest_url("target/list"), post_body
        data_type =  DataType::ASSEMBLY
      else
        raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
      end

      response.render_table(data_type) unless options.list?

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

    desc "TARGET-NAME/ID converge", "Converges target instance"
    def converge(target_id)
      not_implemented()
    end

    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn = conn if @conn.nil?
        response = post rest_url("target/list")
        unless response.nil?
          response['data'].each do |element|
            return true if (element['id'].to_s==value || element['display_name'].to_s==value)
          end
        end
        return false
      end
    end
    
  end
end

