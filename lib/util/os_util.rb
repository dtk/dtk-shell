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
dtk_require_from_base('domain/response')
dtk_require_from_base('auxiliary')
require 'highline'
require 'readline'

module DTK
  module Client
    module OsUtil

      extend Auxiliary

      DTK_IDENTITY_FILE = 'dtk.pem'

      class << self
        def is_mac?
          RUBY_PLATFORM.downcase.include?('darwin')
        end

        def is_windows?
          RUBY_PLATFORM =~ /mswin|mingw|cygwin/
        end

        def is_linux?
          RUBY_PLATFORM.downcase.include?('linux')
        end

        def get_temp_location
          is_windows? ? genv(:temp) : '/tmp'
        end

        def pop_readline_history(number_of_last_commands)
          number_of_last_commands.downto(1) do
            Readline::HISTORY.pop
          end
          nil
        end

        def get_log_location
          return "#{dtk_local_folder}"
        end

        def clear_screen
          command = is_windows? ? "cls" : "clear"
          system(command)
        end

        def dtk_home_dir
          return "#{home_dir}"
        end

        # This will return class object from DTK::Client namespace
        def get_dtk_class(command_name)
          begin
            Object.const_get('DTK').const_get('Client').const_get(cap_form(command_name))
          rescue Exception => e
            return nil
          end
        end

        # for Windows app folder is already under OS username
        def dtk_user_app_folder
          if is_windows?
            dtk_app_folder()
          else
            "#{dtk_app_folder}#{::DTK::Common::Aux.running_process_user()}/"
          end
        end

        def dtk_app_folder
          return (is_windows? ? "#{genv(:homedrive)}#{genv(:homepath)}/dtk/" : "#{/etc/}dtk/")
        end

        def dtk_local_folder
          return (is_windows? ? "#{genv(:homedrive)}#{genv(:homepath)}/dtk/" : "#{home_dir}/dtk/")
        end

        def home_dir
          return (is_windows? ? "#{genv(:homedrive)}#{genv(:homepath)}" : "#{genv(:home)}")
        end

        def current_dir
          current_dir = Dir.getwd()
          current_dir.gsub(home_dir, '~')
        end

        def genv(name)
          return ENV[name.to_s.upcase].gsub(/\\/,'/')
        end

        def edit(file)
          editor = ENV['EDITOR']
          if is_windows?
            raise Client::DtkError, "Environment variable EDITOR needs to be set; exit dtk-shell, set variable and log back into dtk-shell." unless editor
          else
            editor = 'vim' unless editor
          end

          system("#{editor} #{file}")
        end

        def module_location(module_type,module_name,version=nil,opts={})
          # compact used because module_name can be nil
          location = module_location_parts(module_type,module_name,version,opts).compact.join('/')
          location
        end

        # if module location is /a/b/d/mod it returns ['/a/b/d','mod']
        def module_location_parts(module_type,module_name,version=nil,opts={})
          base_path = clone_base_path(opts[:assembly_module] ? :assembly_module : module_type)
          if assembly_module = opts[:assembly_module]
            assembly_name = opts[:assembly_module][:assembly_name]
            base_all_types = "#{base_path}/#{assembly_name}"
            if module_type == :all
              [base_all_types,nil]
            else
              type = clone_base_path(module_type).split('/').last
              ["#{base_all_types}/#{type}", module_name]
            end
          else
            # we detect if we are using full name
            if (module_name.match(/(.*)#{ModuleUtil::NAMESPACE_SEPERATOR}(.*)/))
              [base_path, "#{$1}", "#{$2}#{version && "-#{version}"}"]
            else
              [base_path, "#{module_name}#{version && "-#{version}"}"]
            end
          end
        end

        def module_version_locations(module_type, module_name, version = nil, opts={})
          base_path, namespace, name = module_location_parts(module_type, module_name, version, opts) #.first
          namespace_path = "#{base_path}/#{namespace}"
          module_versions = Dir.entries(namespace_path).select{|a| a.match(/^#{name}-\d{1,2}.\d{1,2}.\d{1,2}$/)}
          module_versions.map{ |version| "#{namespace_path}/#{version}" }
        end

        def module_clone_location(module_type)
          case module_type.to_s
            when "component_module"
              return component_clone_location
            when "service_module"
              return service_clone_location
            when "test_module"
              test_clone_location
            else
              raise Client::DtkError, "Unexpected module_type (#{module_type}) when determining module location"
            end
        end

        def temp_git_remote_location()
          File::join(dtk_local_folder, 'temp_remote_location')
        end

        def component_clone_location()
          clone_base_path(:component_module)
        end

        def service_clone_location()
          clone_base_path(:service_module)
        end

        def test_clone_location()
          clone_base_path(:test_module)
        end

        def assembly_module_base_location()
          clone_base_path(:assembly_module)
        end

        def backups_location()
          path = Config[:backups_location]
          final_path = path && path.start_with?('/') ? path : "#{dtk_local_folder}#{path}"
          final_path.gsub(/\/$/,'')
        end

        def clone_base_path(module_type)

          path =
            case module_type.to_sym
              when :service_module then Config[:service_location]
              when :component_module then Config[:module_location]
              when :test_module then Config[:test_module_location]
              when :assembly_module then Config[:assembly_module_base_location]
              else raise Client::DtkError, "Unexpected module_type (#{module_type}) when determining base path"
            end


          final_path = path && path.start_with?('/') ? path : "#{dtk_local_folder}#{path}"
          # remove last slash if set in configuration by mistake
          final_path.gsub(/\/$/,'')
        end

        #
        # Checks to find dtk.pem in configuration node, if not found displays tip message
        #
        def dtk_identity_file_location()
          path_to_identity_file = "#{dtk_local_folder}#{DTK_IDENTITY_FILE}"
          return path_to_identity_file if File.exists?(path_to_identity_file)
          print("TIP: You can save your identity file as '#{path_to_identity_file}' and it will be used as default identityfile.", :yellow)
          nil
        end


        private :clone_base_path
        #
        #
        #
        def local_component_module_list()
          component_module_dir = component_clone_location()

          directories = Dir.entries(component_module_dir).map do |entry|
            next if (entry =='.' || entry == '..' || entry.index('.') == 0 || !File.directory?(entry))

            Dir.entries("#{component_module_dir}/#{entry}").map do |m_entry|
              next unless File.directory? File.join(component_module_dir,entry,m_entry)
              next if (m_entry =='.' || m_entry == '..' || m_entry.index('.') == 0)

              ModuleUtil.join_name(m_entry, entry)
            end
          end

          directories.flatten.select { |d| !d.nil? }
        end

        # Public method will convert given string, to string with colorize output
        #
        # message - String to be colorized
        # color   - Symbol describing color to be used
        #
        # Returns String with colorize output
        def colorize(message, color)
          # at the moment we do not support colors in windows
          ((is_windows? || message.nil?) ? message : message.colorize(color))
        end

        # Public method will print to STDOUT with given color
        #
        # message - String to be colorize and printed
        # color   - Symbol describing the color to be used on STDOUT
        #
        # Void
        def print(message, color = :white)
          puts colorize(message, color)
        end

        def print_warning(message)
          print(message, :yellow)
        end

        def print_deprecate_message(message)
          print_warning(message)
        end

        # Public block, method will suspend STDOUT, STDERR in body of it
        #
        # Example
        # suspend_output do
        #   # some calls
        # end
        def suspend_output
          if is_windows?
            retval = yield
          else
            orig_stderr = $stderr.clone
            orig_stdout = $stdout.clone
            begin
              $stderr.reopen File.new('/dev/null', 'w')
              $stdout.reopen File.new('/dev/null', 'w')
              retval = yield
            rescue Exception => e
              $stdout.reopen orig_stdout
              $stderr.reopen orig_stderr
              raise e
            ensure
              $stdout.reopen orig_stdout
              $stderr.reopen orig_stderr
            end
          end
          retval
        end

        def which(cmd)
          exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
          ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
            exts.each { |ext|
              exe = File.join(path, "#{cmd}#{ext}")
              return exe if File.executable? exe
            }
          end
          return nil
        end

        def dev_reload_shell()
          suspend_output do
            load File.expand_path('../../lib/util/os_util.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/util/ssh_util.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/util/remote_dependency_util.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/shell/help_monkey_patch.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/shell/domain/context_entity.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/shell/domain/active_context.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/shell/domain/context_params.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/shell/domain/override_tasks.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/shell.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/shell/context.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/domain/git_adapter.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/command_helpers/git_repo.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/command_helpers/service_importer.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/view_processor/table_print.rb', File.dirname(__FILE__))
            load File.expand_path('../../lib/shell/interactive_wizard.rb', File.dirname(__FILE__))
            paths = []
            paths << File.expand_path('../../lib/commands/thor/*.rb', File.dirname(__FILE__))
            paths << File.expand_path('../../lib/commands/common/thor/*.rb', File.dirname(__FILE__))

            paths.each do |path|
              Dir[path].each do |thor_class_file|
                load thor_class_file
              end
            end
          end
        end

        def put_warning(prefix, text, color)
          width = HighLine::SystemExtensions.terminal_size[0] - (prefix.length + 1)
          text_split = wrap(text, width)
          Kernel.print colorize(prefix, color), " "
          text_split.lines.each_with_index do |line, index|
            line = " "*(prefix.length + 1) + line unless index == 0
            puts line
          end
        end

        def wrap(text, wrap_at)
          wrapped = [ ]
          text.each_line do |line|
          # take into account color escape sequences when wrapping
          wrap_at = wrap_at + (line.length - actual_length(line))
          while line =~ /([^\n]{#{wrap_at + 1},})/
            search  = $1.dup
            replace = $1.dup
            if index = replace.rindex(" ", wrap_at)
              replace[index, 1] = "\n"
              replace.sub!(/\n[ \t]+/, "\n")
              line.sub!(search, replace)
            else
              line[$~.begin(1) + wrap_at, 0] = "\n"
            end
          end
          wrapped << line
          end
          return wrapped.join
        end

        def actual_length( string_with_escapes )
          string_with_escapes.to_s.gsub(/\e\[\d{1,2}m/, "").length
        end

        def remove_html_tags(string_with_tags)
          string_with_tags.gsub(/<\/?[^>]+>/, '')
        end

        private

        def seperator
          return (is_windows? ? "\\" : "/")
        end
      end
    end
  end
end
