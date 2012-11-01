module DTK::Client
  class ComponentTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:component)
    end

    desc "COMPONENT-NAME/ID info", "Get information about given component template."
    method_option :list, :type => :boolean, :default => false
    def info(component_id=nil)
      data_type = :component

      post_body = {
        :component_id => component_id,
        :subtype => 'template'
      }
      response = post rest_url("component/info"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "COMPONENT-NAME/ID list nodes", "List all nodes for given component template."
    method_option :list, :type => :boolean, :default => false
    def list(nodes='none', component_id=nil)
      data_type = :component

      post_body = {
        :component_id => component_id,
        :subtype => 'template',
        :about   => nodes
      }

      case nodes
      when 'none'
        response = post rest_url("component/list")
      when 'nodes'
        response = post rest_url("component/list"), post_body
      else
        raise DTK::Client::DtkError, "Not supported type '#{nodes}' for given command."
      end

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "COMPONENT-NAME/ID stage NODE-NAME/ID", "Stage indentified node for given component template."
    method_option :list, :type => :boolean, :default => false
    def stage(node_id, component_id=nil)
      data_type = :component

      post_body = {
        :component_id => component_id
      }

      unless node_id.nil?
        post_body.merge!({:node_id => node_id})
      end
      
      response = post rest_url("component/stage"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:component_template, "component/list", {:subtype => 'template'})

        unless (response.nil? || response.empty? || response['data'].nil?)
          response['data'].each do |element|
            return true if (element['id'].to_s==value || element['display_name'].to_s==value)
          end
          return false
        end
        
        # if response is ok but response['data'] is nil, display warning message
        DtkLogger.instance.warn("Response data is nil, please check if your request is valid.")
        return false
      end

      def self.get_identifiers(conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:component_template, "component/list", {:subtype => 'template'})

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

