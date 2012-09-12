require 'hirb'
require 'ostruct'

# we override String here to give power to our mutators defined in TableDefintions
class String
  def get_date
    DateTime.parse(self).strftime('%H:%M:%S %d/%m/%y') unless self.nil?
  end
end

module DTK
  module Client
    class ViewProcTablePrint < ViewProcessor
      def render(data, command_clazz, data_type_clazz)
        DtkResponse.new(data, data_type_clazz).print
      end
    end

    private

    # when adding class to table view you need to define mapping and order to be displayed in table
    # this can be fixed with facets, but that is todo for now TODO: use facets with ordered hashes
    class TableDefinitions
      ASSEMBLY            = { :assembly_id=>"dtk_id", :assembly_name => "display_name", :nodes => "nodes.size", :components => "nodes.first['components'].join(', ')" }
      ASSEMBLY_ORDER      = [ :assembly_id, :assembly_name, :nodes, :components ]
      TASK                = { :task_id => "dtk_id", :status => "status.upcase", :created => "created_at.get_date", :start => "started_at.get_date", :end => "ended_at.get_date"}
      TASK_ORDER          = [ :task_id,:status, :created, :start, :end ]
      NODE                = { :node_id => "dtk_id", :name => "display_name", :node_type => "external_ref.dtk_type", :region => "external_ref.region", :instance_id => "external_ref.instance_id", :size => "external_ref.size.split('.').last", :zone => "external_ref.availability_zone", :os => "os_type", :dns_name => "external_ref.dns_name" }
      NODE_ORDER          = [ :node_id, :name, :node_type, :region, :instance_id, :size, :zone, :os, :dns_name ]
      NODE_TEMPLATE       = { :node_template_id => "dtk_id", :name => "display_name", :template_type => "template_type", :size => "size.split('.').last", :os => "os_type" }
      NODE_TEMPLATE_ORDER = [ :node_template_id, :name, :template_type, :size, :os]
      REMOTE_MODULE       = { :name => "display_name", :version => "version" }
      REMOTE_MODULE_ORDER = [:name, :version ]
      MODULE              = { :module_id => "dtk_id", :name => "display_name", :version => "version" }
      MODULE_ORDER        = [ :module_id, :name, :version ]
      TARGET              = { :target_id => "dtk_id", :target_type => "dtk_type", :iaas => "iaas_type", :description => "description"}
      TARGET_ORDER        = [ :target_id, :target_type, :iaas, :description]
      LIBRARY             = { :library_id => "dtk_id", :library_name => "display_name" }
      LIBRARY_ORDER       = [ :library_id, :library_name ]      
      COMPONENT           = { :component_id => "dtk_id", :name => "display_name", :component_type => "dtk_type", :version=>"version", :library => "library.display_name", :library_id => "library_library_id" }
      COMPONENT_ORDER     = [ :component_id, :name, :component_type, :version, :library, :library_id ]
    end

    class DtkResponse

      include Hirb::Console

      attr_accessor :command_name, :order_defintion, :evaluated_data

      def initialize(data, data_type)
        # use this to see data structure
        # puts data.first.inspect

        # e.g. data type ASSEMBLY
        @command_name     = data_type
        # e.g. ASSEMBLY => TableDefintions::ASSEMBLY
        table_defintion   = get_table_defintion(@command_name)
        # e.g. ASSEMBLY => TableDefintions::ASSEMBLY_ORDER
        @order_definition = get_table_defintion("#{@command_name}_ORDER")

        # if one defintion is missing we stop the execution
        if table_defintion.nil? || @order_definition.nil?
          raise DTK::Client::DtkError,"Missing table definition(s) for data type #{data_type}."
        end

        # transforms data to OpenStruct
        structured_data = []
        data.each do |data_element|
          structured_data << to_ostruct(data_element)
        end

        # we use array of OpenStruct to hold our evaluated values
        @evaluated_data = []
        structured_data.each do |structured_element|
          evaluated_element = OpenStruct.new
          # based on mappign we set key = eval(value)
          table_defintion.each do |k,v|
            begin
              eval "evaluated_element.#{k}=structured_element.#{v}"
            rescue NoMethodError => e
              unless e.message.include? "nil:NilClass"
                # when chaining comands there are situations where more complex strcture
                # e.g. external_ref.region will not be there. So we are handling that case
                # make sure when in development to disable this TODO: better solution needed
                raise e
              end
            end 
          end
          @evaluated_data << evaluated_element
        end
      end

      def to_ostruct(data)
        arr = data.map do |k, v|
          k = safe_name(k)
          case v
          when Hash
            [k, to_ostruct(v)]
          when Array
            [k, v.each { |el| Hash === el ? to_ostruct(el) : el }]
          else
            [k,v]
          end
        end
        OpenStruct.new(arr)
      end

      def safe_name(identifier)
        (identifier == 'id' || identifier  == 'type') ? "dtk_#{identifier}" : identifier
      end

      def get_table_defintion(name)
        begin
          TableDefinitions.const_get(name)
        rescue NameError => e
          return nil
        end
      end

      def print
        # hirb print out of our evaluated data in order defined
        table @evaluated_data,:fields => @order_definition
      end

    end

  end
end




