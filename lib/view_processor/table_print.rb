require 'hirb'

module DTK
  module Client
    class ViewProcTablePrint < ViewProcessor

      def render(data, command_class)
        TableFactory.print_table(data, command_class)
      end
    end

    ##
    # Since hirb is not very flexible to way is creates tables with data
    # we will use following class as container for the response. Via this
    # class we are going to manipulate data structure so we get desired 
    # console table output (via hirb).
    #
    class TableFactory
      def self.print_table(data, command_class)

        # would be better to use class directly but that way we need to ensure that all are loaded.
        # we can check if they are loaded before checking class but this is faster solution.
        case command_class.to_s
          when "DTK::Client::Assembly"
            DtkResponse.new(data, DtkElement).print
          when "DTK::Client::Task"
            DtkResponse.new(data, DtkTaskElement).print
          else
            raise DTK::Client::DtkError,"Missing table implementation for #{command_class}."
          end
      end
    end

    private

    class DtkResponse

      include Hirb::Console

      attr_accessor :elements, :element_clazz

      def initialize(data, data_clazz)
        @elements, @element_clazz = [], data_clazz

        data.each do |element|
          @elements << data_clazz.new(element)
        end

      end

      def print
        table @elements,:fields => @element_clazz::FIELDS
      end

    end

    class DtkTaskElement
      FIELDS = [:id,:status, :created, :start, :end]
      FIELDS.each { |field| attr_accessor field }

      def initialize(element)
        @status   = element['status'].upcase
        @id       = element['id']
        @created  = get_date element['created_at']
        @start    = get_date element['started_at']
        @end      = get_date element['ended_at']
      end

      private

      def get_date(string_date)
        DateTime.parse(string_date).strftime('%H:%M:%S %d/%m/%y') unless string_date.nil?
      end

    end

    class DtkElement

      FIELDS = [:assembly_id, :assembly_name, :nodes, :components]
      FIELDS.each { |field| attr_accessor field }

      def initialize(element)
        @assembly_id    = element['id']
        @assembly_name  = element['display_name']
        @nodes          = element['nodes'].size
        
        all_components  = []
        element['nodes'].each { |node| all_components << node['components']}
        @components = all_components.uniq
      end

    end

    class DtkNode
      attr_accessor :node_id, :node_name, :components, :region, :size
      def initialize(element)
        @node_id    = element['node_id']
        @node_name  = element['node_name']
        @size       = element['external_ref']['size']
        @region     = element['external_ref']['region']
        @components = element['components`']
      end
    end
  end
end




