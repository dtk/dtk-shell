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
require 'optparse'
module DTK
  module Client
    class CommandBaseOptionParser
      include CommandBase
      def initialize(conn)
        @conn = conn
      end

      def self.execute_from_cli(conn,argv,shell_execute=false)
        return conn.connection_error if conn.connection_error
        method, args_hash = OptionParser.parse_options(self,argv)
        instance = new(conn)
        raise Error.new("Illegal subcommand #{method}") unless instance.respond_to?(method)
        instance.send(method,args_hash)
      end
      class << self
        include Auxiliary
        def command_name()
          snake_form(self,"-")
        end
      end
    end
    class OptionParser
      def self.parse_options(command_class,argv)
        args_hash = Hash.new
        unless subcommand = argv[0]
          raise Error.new("No subcommand given")
        end
        method = subcommand.to_sym
        unless parse_info = (command_class.const_get "CLIParseOptions")[subcommand.to_sym]
          return [method,args_hash]
        end
        ::OptionParser.new do|opts|
          opts.banner = "Usage: #{command_class.command_name} #{subcommand} [options]"
          (parse_info[:options]||[]).each do |parse_info_option|
            raise Error.new("missing param name") unless param_name = parse_info_option[:name]
            raise Error.new("missing optparse spec") unless parse_info_option[:optparse_spec]
            opts.on(*parse_info_option[:optparse_spec]) do |val|
              args_hash[param_name.to_s] = val ? val : true
            end
          end

          opts.on('-h', '--help', 'Display this screen') do
            puts opts
            exit
          end
        end.parse!(argv)
        [method,args_hash]
      end
    end
  end
end
