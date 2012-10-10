module DTK::Client
  class NodeTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:node)
    end

    desc "NODE-NAME/ID info", "Get information about given node template."
    method_option :list, :type => :boolean, :default => false
    def info(node_id=nil)
      data_type = :node

      post_body = {
        :node_id => node_id,
        :subtype => 'template'
      }
      response = post rest_url("node/info"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "NODE-TEMPLATE-NAME/ID list", "List all node templates."
    def list()
      post_body = {
        :subtype => 'template'
      }
      response = post rest_url("node/list")
      response.render_table(:node)
    end


    desc "NODE-NAME/ID stage TARGET-NAME/ID", "Stage indentified target for given node template."
    method_option :list, :type => :boolean, :default => false
    def stage(target_id, node_id=nil)
      data_type = :node

      post_body = {
        :node_id => node_id
      }

      unless target_id.nil?
        post_body.merge!({:target_id => target_id})
      end
      
      response = post rest_url("node/stage"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end


    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:node_template, "node/list", {:subtype => 'template'})

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
        response = get_cached_response(:node_template, "node/list", {:subtype => 'template'})

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

