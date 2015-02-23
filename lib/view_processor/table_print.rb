require 'hirb'
require 'ostruct'
require 'colorize'
require 'rest_client'
require 'json'

dtk_require("../config/disk_cacher")

# we override String here to give power to our mutators defined in TableDefintions
class String
  def get_date
    DateTime.parse(self).strftime('%H:%M:%S %d/%m/%y') unless self.nil?
  end
end

# override OpenStruct to remove defintion for id
class DtkOpenStruct < OpenStruct
  if RUBY_VERSION.match(/^1\.8\..*$/)
    undef id
    undef type
  end
end

module DTK
  module Client
    class ViewProcTablePrint < ViewProcessor
      def render(data, command_clazz, data_type_clazz, forced_metadata=nil, print_error_table=false)
        DtkResponse.new(data, data_type_clazz, forced_metadata, print_error_table).print
      end
    end

    class DtkResponse

      include Hirb::Console
      include CommandBase
      extend  CommandBase
      attr_accessor :command_name, :order_defintion, :evaluated_data

      # when adding class to table view you need to define mapping and order to be displayed in table
      # this can be fixed with facets, but that is todo for now TODO: use facets with ordered hashes

      def initialize(data, data_type, forced_metadata, print_error_table)
        # if there is no custom metadata, then we use metadata predefined in meta-response.json file
        if forced_metadata.nil?
          # get all table definitions from json file
          @table_defintions = get_metadata()
          # e.g. data type ASSEMBLY
          @command_name     = data_type
          # e.g. ASSEMBLY => TableDefintions::ASSEMBLY
          table_defintion   = get_table_defintion(@command_name)
          # e.g. ASSEMBLY => TableDefintions::ASSEMBLY_ORDER
          @order_definition = get_table_defintion(@command_name, true)
        else
          # if there is custom metadata, check if it is in valid format
          validate_forced_metadata(forced_metadata)

          table_defintion   = forced_metadata['mapping']
          @order_definition = forced_metadata['order']
        end

        # if one defintion is missing we stop the execution
        if table_defintion.nil? || @order_definition.nil?
          raise DTK::Client::DtkError,"Missing table definition(s) for data type #{data_type}."
        end

        # transforms data to DtkOpenStruct
        structured_data = []

        # very important since rest of the code expect array to be used
        data = [data] unless data.kind_of?(Array)

        data.each do |data_element|
          # special flag to filter out data not needed here
          next if data_element['dtk_client_hidden']

          structured_data << to_ostruct(data_element)
        end

        # we use array of OpenStruct to hold our evaluated values
        @evaluated_data = []
        @error_data     = []
        @action_data    = []
        structured_data.each do |structured_element|
          evaluated_element = DtkOpenStruct.new
          error_element     = DtkOpenStruct.new

          # based on mappign we set key = eval(value)
          table_defintion.each do |k,v|
            begin
              # due to problems with space we have special way of handling error columns
              # in such a way that those error will be specially printed later on

              if print_error_table && k.include?('error')
                error_message = value_of(structured_element, v)
                server_error = nil

                # here we see if there was an error if not we will skip this
                # if so we add it to @error_data

                if error_message.empty?
                  # no error message just add it as regular element
                  evaluated_element.send("#{k}=",value_of(structured_element, v))
                else
                  error_index = ""
                  error_type = value_of(structured_element,'errors.dtk_type') || ""

                  val = value_of(structured_element,'dtk_type')||''
                  # extract e.g. 3.1.1.1 from '3.1.1.1 action' etc.
                  error_index = "[ #{val.scan( /\d+[,.]\d?[,.]?\d?[,.]?\d?[,.]?\d?/ ).first} ]"

                  # original table takes that index
                  evaluated_element.send("#{k}=", error_index)
                  # we set new error element
                  error_element.id = error_index

                  if error_type == "user_error"
                    error_element.message = "[USER ERROR] " + error_message
                  elsif error_type == "test_error"
                    error_element.message = "[TEST ERROR] " + error_message
                  else
                    error_element.message = "[SERVER ERROR] " + error_message
                  end

                  # add it with other
                  @error_data << error_element
                end
              elsif k.include?('action')
                error_message = value_of(structured_element, v)

                # here we see if there was an error if not we will skip this
                # if so we add it to @error_data

                if error_message.empty?
                  # no error message just add it as regular element
                  evaluated_element.send("#{k}=",value_of(structured_element, v))
                else
                  error_index = "[ #{value_of(structured_element,'logs.label')} ]" || ""
                  error_type = value_of(structured_element,'logs.dtk_type') || ""

                  # original table takes that index
                  evaluated_element.send("#{k}=", error_index)

                  # we set new error element
                  error_element.id      = error_index
                  error_element.message = error_message

                  # add it with other
                  @action_data << error_element
                end
              else
                evaluated_element.send("#{k}=", value_of(structured_element, v))
                # eval "evaluated_element.#{k}=structured_element.#{v}"
              end
            rescue NoMethodError => e
              unless e.message.include? "nil:NilClass"
                # when chaining comands there are situations where more complex strcture
                # e.g. external_ref.region will not be there. So we are handling that case
                # make sure when in development to disable this TODO: better solution needed
                raise DTK::Client::DtkError,"Error with missing metadata occurred. There is a mistake in table metadata or unexpected data presented to table view."
              end
            end
          end

          @order_definition.delete('action')
          @order_definition.delete('errors')

          @evaluated_data << evaluated_element
        end
      end

      def get_metadata
        content = DiskCacher.new.fetch("table_metadata", ::DTK::Configuration.get(:meta_table_ttl))
        raise DTK::Client::DtkError, "Table metadata is empty, please contact DTK team." if content.empty?
        return JSON.parse(content)
      end

      def to_ostruct(data)
        result = data.inject({}) do |res, (k, v)|
          k = safe_name(k)
          case v
          when Hash
            res.store(k, to_ostruct(v))
            res
          when Array
            res.store(k, v.each { |el| Hash === el ? to_ostruct(el) : el })
            res
          else
            res.store(k,v)
            res
          end
        end

        DtkOpenStruct.new(result)
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

      # Check if custom metadata is sent in valid format
      def validate_forced_metadata(forced_metadata)
        # if custom metadata does not contain order(Array) or mapping(Hash),then it's not valid metadata
        unless (forced_metadata['order'].nil? || forced_metadata['mapping'].nil?)
          return if (forced_metadata['order'].class.eql?(Array) && forced_metadata['mapping'].class.eql?(Hash))
        end

        raise DTK::Client::DtkError,"Provided table definition is not valid. Please review your order and mapping for provided definition: \n #{forced_metadata.inspect}"
      end

      def filter_remove_underscore(field)

      end

      def print
        filter_remove_underscore = Proc.new { |header| header.gsub('_',' ').upcase }
        # hirb print out of our evaluated data in order defined
        # Available options can be viewed here: http://tagaholic.me/hirb/doc/classes/Hirb/Helpers/Table.html#M000008
        table(@evaluated_data,{:fields => @order_definition,:escape_special_chars => true, :resize => false, :vertical => false, :header_filter => filter_remove_underscore })

        # in case there were error we print those errors
        unless @error_data.empty?
          printf "\nERRORS: \n\n"
          #table(@error_data,{:fields => [ :id, :message ]})
          @error_data.each do |error_row|
            printf "%15s %s\n", error_row.id.colorize(:yellow), error_row.message.colorize(:red)
          end
        end

        unless @action_data.empty?
          printf " \n"
          #table(@error_data,{:fields => [ :id, :message ]})
          printed = []
          @action_data.each do |action_row|
            # printf "%15s\n"
            # printf("  INFO: #{action_row.message.colorize(:yellow)} \n") #, action_row.id.colorize(:yellow), action_row.message.colorize(:yellow)
            message = action_row.message
            printf "%15s %s\n", "INFO:".colorize(:yellow), message.colorize(:yellow) unless printed.include?(message)
            printed << message
          end
        end
      end

      private

      # based on string sequence in mapped_command we are executing list of commands to follow
      # so for value of "foo.bar.split('.').last" we will get 4 commands that will
      # sequentaly be executed using values from previus results
      def value_of(open_struct_object, mapped_command)
        # split string by '.' delimiter keeping in mind to split when words only
        commands = mapped_command.split(/\.(?=\w)/)

        value = open_struct_object
        commands.each do |command|
          value = evaluate_command(value, command)
        end
        return value
      end


      def evaluate_command(value, command)
        case
          when command.include?('map{')
            matched_data = command.match(/\['(.+)'\]/)

            my_lambda = lambda{|_x| _x.map{|r|r["#{matched_data[1]}"]||[]}}
            value = my_lambda.call(value)

            raise DTK::Client::DtkError,"There is a mistake in table metadata: #{command.inspect}" if value.nil?
          when command.include?('(')
            # matches command and params e.g. split('.') => [1] split, [2] '.'
            matched_data = command.match(/(.+)\((.+)\)/)
            command, params = matched_data[1], matched_data[2]
            value = value.send(command,params)
          when command.include?('[')
            # matches command such as first['foo']
            matched_data    = command.match(/(.+)\[(.+)\]/)
            command, params =  matched_data[1],matched_data[2]

            value = evaluate_command(value,command)
            value = value.send('[]',params)
          when command.start_with?("list_")
            matched_data = command.match(/list_(.+)/)

            my_lambda = lambda{|_x| _x.map{|r|r["#{matched_data[1]}"]||[]}}
            value = my_lambda.call(value)

            raise DTK::Client::DtkError,"There is a mistake in table metadata: #{command.inspect}" if value.nil?
          when command.start_with?("count_")
            matched_data = command.match(/count_(.+)/)

            my_lambda = lambda{|_x| _x.map{|r|r["#{matched_data[1]}"]||[]}.flatten.size}
            value = my_lambda.call(value)

            raise DTK::Client::DtkError,"There is a mistake in table metadata: #{command.inspect}" if value.nil?
          else
            value = value.send(command)
        end
        return value
      end
    end
  end
end




