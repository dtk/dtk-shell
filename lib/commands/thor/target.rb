module DTK::Client
  class Target < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:target)
    end

    desc "create TARGET-NAME [DESCRIPTION]","Create new target"
    def create(target_id,description=nil)
      post_body = {
        :target_name => target_id,
        :description => description
      }
       post rest_url("target/create"), post_body
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
    end

    desc "TARGET-NAME/ID converge", "Converges target instance"
    def converge(target_id)
      not_implemented()
    end

    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:target, "target/list")

        unless (response.nil? || response.empty?)
          unless response['data'].nil?
            response['data'].each do |element|
              return true if (element['id'].to_s==value || element['display_name'].to_s==value)
            end
          end
          
          # if response is ok but response['data'] is nil, display warning message
          DtkLogger.instance.warn("Response data is nil, please check if your request is valid.")
        end
        return false
      end

      def self.get_identifiers(conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:target, "target/list")

        unless (response.nil? || response.empty?)
          unless response['data'].nil?
            identifiers = []
            response['data'].each do |element|
               identifiers << element['display_name']
            end
            return identifiers
          end

          # if response is ok but response['data'] is nil, display warning message
          DtkLogger.instance.warn("Response data is nil, please check if your request is valid.")
        end
        return []
      end
    end
    
  end
end

