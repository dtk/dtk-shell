#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This is wrapper for holding rest response information as well as
# passing selection of ViewProcessor from Thor selection to render view
# selection
require 'git'

module DTK
  module Client
    #TODO: should make higher level class be above whether it is 'rest'
    class Response < Common::Response
      require File.expand_path('response/error_handler',File.dirname(__FILE__))
      include ErrorHandlerMixin

      # :render_view        => symbol specifing type of data to be rendered e.g. :assembly
      # :skip_render        => flag that specifies that render is not needed (default: false)
      # :print_error_table  => we use it if we want to print 'error legend' for given tables (default: false)
      attr_accessor :render_view, :skip_render, :print_error_table

      # Amar: had to add this in order to get json meta for PP that's not for domain class
      def override_command_class(json_top_type)
        @command_class = json_top_type
      end

      def initialize(command_class=nil,hash={})
        super(hash)
        @command_class     = command_class
        @skip_render       = false
        @print_error_table = false
        # default values
        @render_view = RenderView::AUG_SIMPLE_LIST
        @render_data_type = nil
      end

      def clone_me()
        return Marshal.load(Marshal.dump(self))
      end

      def self.wrap_helper_actions(data={},&block)
        begin
          results = (block ? yield : data)
          Ok.new(results)

        rescue Git::GitExecuteError => e
          if e.message.include?('Please make sure you have the correct access rights')
            error_msg  = "You do not have git access from this client, please add following SSH key in your git account: \n\n"
            error_msg += SSHUtil.rsa_pub_key_content() + "\n"
            raise DTK::Client::DtkError, error_msg
          end
          handle_error_in_wrapper(e)
        rescue ErrorUsage => e
          Error::Usage.new("message"=> e.to_s)
        rescue => e
          handle_error_in_wrapper(e)
        end
      end

      def self.handle_error_in_wrapper(exception)
        error_hash =  {
          "message"=> exception.message,
          "backtrace" => exception.backtrace,
          "on_client" => true
          }

        if DTK::Configuration.get(:development_mode)
          DtkLogger.instance.error_pp("Error inside wrapper DEV ONLY: #{exception.message}", exception.backtrace)
        end

        Error::Internal.new(error_hash)
      end

      def get_label_for_column_name(column, type)
        if type.eql?('node')
          mappings = {
            column => column
          }
        else
          mappings = {
            "#{type}_id:" => "ID:",
            "#{type}_name:" => "NAME:",
            "node_type:" => "TYPE:",
            "instance_id:" => "INSTANCE ID:",
            "size:" => "SIZE:",
            "os_type:" => "OS:",
            "op_status:" => "OP STATUS:",
            "dns_name:" => "DNS NAME:",
            "target:" => "TARGET:"
          }
        end

        mappings[column]
      end

      # used just for printing workspace node info
      def render_workspace_node_info(type)
        info_list = ""
        if type.eql?("component")
          info_list = ["component_name","component_id","basic_type","description"]
        else
          info_list = ["type", "node_id", "node_name","os_type", "instance_id", "admin_op_status", "size", "target", "dns_name", "image_id", "ec2_public_address", "privete_dns_name", "keypair", "security_groups", "security_group", "security_group_set"]
        end

        columns = []
        puts "--- \n"
        if data.kind_of?(String)
          data.each_line do |l|
            print = "#{l.gsub(/\s+\-*\s+/,'')}"
            print.gsub!(/-\s+/,"")
            info_list.each do |i|
              if match = print.to_s.match(/^(#{i}:)(.+)/)
                label = get_label_for_column_name(match[1], type)
                columns << " #{label}#{match[2]}\n"
              end
            end
          end
        end

        if type.eql?('node')
          # move target from first place
          columns.rotate!
        else
          columns.sort!()
        end

        columns.each do |column|
          STDOUT << column
        end
        puts "\n"
      end

      def render_custom_info(type)
        puts "--- \n"

        unless data.empty?
          data.each do |k,v|
            label = get_custom_labels(k, type)
            v = array_to_string(v) if v.is_a?(Array)
            STDOUT << " #{label} #{v}\n" if label
          end
        end

        puts "\n"
      end

      def get_custom_labels(label, type)
        mappings = {}

        mappings["module"] = {
          "id" => "ID:",
          "display_name" => "NAME:",
          "versions" => "VERSION(S):",
          "remote_repos" => "LINKED REMOTE(S):",
          "dsl_parsed" => "DSL PARSED:"
        }

        mappings[type][label] if mappings[type]
      end

      def array_to_string(array_data)
        info = ""
        array_data.each do |a|
          info << "#{a.values.first},"
        end

        "#{info.gsub!(/,$/,'')}"
      end


      def render_data(print_error_table=false)
        unless @skip_render
          if ok?()

            @print_error_table ||= print_error_table

            # if response is empty, response status is ok but no data is passed back
            if data.empty? or (data.is_a?(Array) ? data.first.nil? : data.nil?)
              @render_view = RenderView::SIMPLE_LIST
              if data.kind_of?(Array)
                set_data('Message' => "List is empty.")
              else #data.kind_of?(Hash)
                set_data('Status' => 'OK')
              end
            end

            # sending raw data from response
            rendered_data = ViewProcessor.render(@command_class, data, @render_view, @render_data_type, nil, @print_error_table)

            puts "\n" unless rendered_data
            return rendered_data
          else
            hash_part()
          end
        end
      end

      def render_arg_list!
        @render_view = RenderView::AUG_SIMPLE_LIST
      end

      def set_datatype(data_type)
        @render_data_type = symbol_to_data_type_upcase(data_type)
        self
      end

      def render_table(default_data_type=nil, use_default=false)
        unless ok?
          return self
        end
        unless data_type = (use_default ? default_data_type : (response_datatype() || default_data_type))
          raise DTK::Client::DtkError, "Server did not return datatype."
        end

        @render_data_type = symbol_to_data_type_upcase(data_type)
        @render_view = RenderView::TABLE
        self
      end

      def response_datatype()
        self["datatype"] && self["datatype"].to_sym
      end

      def hash_part()
        keys.inject(Hash.new){|h,k|h.merge(k => self[k])}
      end

      def symbol_to_data_type_upcase(data_type)
        return data_type.nil? ? nil : data_type.to_s.upcase
      end

      private :hash_part

      class Ok < self
        def initialize(data={})
          super(nil,{"data"=> data, "status" => "ok"})
        end
      end

      class NotOk < self
        def initialize(data={})
          super(nil,{"data"=> data, "status" => "notok"})
        end
      end

      class Error < self
        include Common::Response::ErrorMixin
        def initialize(hash={})
          super(nil,{"errors" => [hash]})
        end

        class Usage < self
          def initialize(hash_or_string={})
            hash = (hash_or_string.kind_of?(String) ? {'message' => hash_or_string} : hash_or_string)
            super({"code" => "error"}.merge(hash))
          end
        end

        class Internal < self
          def initialize(hash={})
            super({"code" => "error"}.merge(hash).merge("internal" => true))
          end
        end
      end

      class NoOp < self
        def render_data
        end
      end
    end
  end
end
