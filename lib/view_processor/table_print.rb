require 'hirb'
require 'ostruct'

dtk_require("../config/disk_cacher")

# we override String here to give power to our mutators defined in TableDefintions
class String
  def get_date
    DateTime.parse(self).strftime('%H:%M:%S %d/%m/%y') unless self.nil?
  end
end

# override OpenStruct to remove defintion for id
class DtkOpenStruct < OpenStruct
  undef id
end

module DTK
  module Client
    class ViewProcTablePrint < ViewProcessor
      def render(data, command_clazz, data_type_clazz)
        DtkResponse.new(data, data_type_clazz).print
      end
    end

    class DtkResponse

      include Hirb::Console

      attr_accessor :command_name, :order_defintion, :evaluated_data

      # when adding class to table view you need to define mapping and order to be displayed in table
      # this can be fixed with facets, but that is todo for now TODO: use facets with ordered hashes

      def initialize(data, data_type)
        # use this to see data structure
        # puts data.first.inspect

        @table_defintions = get_metadata()     

        # e.g. data type ASSEMBLY
        @command_name     = data_type
        # e.g. ASSEMBLY => TableDefintions::ASSEMBLY
        table_defintion   = get_table_defintion(@command_name)
        # e.g. ASSEMBLY => TableDefintions::ASSEMBLY_ORDER
        @order_definition = get_table_defintion(@command_name, true)

        # if one defintion is missing we stop the execution
        if table_defintion.nil? || @order_definition.nil?
          raise DTK::Client::DtkError,"Missing table definition(s) for data type #{data_type}."
        end

        # transforms data to DtkOpenStruct
        structured_data = []
        data.each do |data_element|
          structured_data << to_ostruct(data_element)
        end

        # we use array of OpenStruct to hold our evaluated values
        @evaluated_data = []
        structured_data.each do |structured_element|
          evaluated_element = DtkOpenStruct.new
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

      def get_metadata
        # TODO: replace this with proper call, 1200000 is age of the request in this case 20 mins
        content = DiskCacher.new.fetch("http://localhost/mockup/get_table_metadata", ::Config::Configuration.get(:caching_url,:meta_table_ttl))
        #FakeWeb.register_uri(:get, "http://localhost/mockup/get_table_metadata", :body => "Hello World!")
        #response = Net::HTTP.get(URI.parse("http://localhost/mockup/get_table_metadata"))
        #content = File.open(File.expand_path('../../test.json',File.dirname(__FILE__)),'rb').read
        raise DTK::Client::DtkError, "Table metadata is empty, please contact DTK team." if content.empty?
        return JSON.parse(content)
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
        DtkOpenStruct.new(arr)
      end

      def safe_name(identifier)
        (identifier == 'id' || identifier  == 'type') ? "dtk_#{identifier}" : identifier
      end

      def get_table_defintion(name,is_order=false)
        begin
          @table_defintions[name.downcase][(is_order ? 'order' : 'mapping')]
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




