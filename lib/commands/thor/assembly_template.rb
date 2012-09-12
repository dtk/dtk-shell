module DTK::Client
  class AssemblyTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns::ASSEMBLY
    end

    desc "ASSEMBLY-NAME/ID info", "Get information about given assembly template."
    method_option :list, :type => :boolean, :default => false
    def info(assembly_id=nil)
      data_type = DataType::ASSEMBLY

      post_body = {
        :assembly_id => assembly_id,
        :subtype => 'template',
      }
      post rest_url("assembly/info"), post_body
    end

    desc "[ASSEMBLY-NAME/ID] list [nodes|components|targets]", "List all nodes/components/targets for given assembly template."
    method_option :list, :type => :boolean, :default => false
    def list(arg1=nil,arg2=nil)
      about, assembly_id = 
        if arg1.nil? then ['none']
        elsif arg2.nil? then ['none',arg1]
        else [arg1,arg2]
      end

      post_body = {
        :assembly_id => assembly_id,
        :subtype => 'template',
        :about => about
      }

      case about
      when 'none'
        response = post rest_url("assembly/list"), {:subtype => 'template'}
        data_type = DataType::ASSEMBLY
      when 'nodes'
        response = post rest_url("assembly/info_about"), post_body
        data_type = DataType::NODE_TEMPLATE
      when 'components'
        response = post rest_url("assembly/info_about"), post_body
        data_type = DataType::COMPONENT
      when 'targets'
        response = post rest_url("assembly/info_about"), post_body
        data_type = DataType::TARGET
      else
        raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
      end

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "ASSEMBLY-NAME/ID stage TARGET-NAME/ID", "Stage indentified target for given assembly template."
    method_option :list, :type => :boolean, :default => false
    def stage(target_id, assembly_id=nil)
      data_type = DataType::ASSEMBLY

      post_body = {
        :assembly_id => assembly_id
      }

      unless target_id.nil?
        post_body.merge!({:target_id => target_id})
      end
      
      response = post rest_url("assembly/stage"), post_body

      response.render_table(data_type) unless options.list?

      return response
    end

  end
end

