dtk_require_from_base('domain/response')

module DTK
  module Client
    module OsUtil
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

        def get_log_location
          if is_windows?
            return "#{genv(:appdata)}/DTK"
          else
  	  			# returns log_path for current user e.g /var/log/user1
            return "/var/log/dtk/#{::DTK::Common::Aux.running_process_user()}"
          end
        end

        def clear_screen
          command = is_windows? ? "cls" : "clear"
          system(command)
        end

        def dtk_home_dir
          return "#{home_dir}"
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
          return (is_windows? ? "#{genv(:homedrive)}#{genv(:homepath)}/dtk/" : "/etc/dtk/")
        end

        def home_dir
          return (is_windows? ? "#{genv(:homedrive)}#{genv(:homepath)}" : "#{genv(:home)}")
        end

        def genv(name)
          return ENV[name.to_s.upcase].gsub(/\\/,'/')
        end

        def module_clone_location()
          module_location = ::Config::Configuration.get(:module_location)
          return (module_location.start_with?('/') ? module_location : "#{home_dir}/#{module_location}")
        end

        def service_clone_location()
          service_location = ::Config::Configuration.get(:service_location)
          return (service_location.start_with?('/') ? service_location : "#{home_dir}/#{service_location}")
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
        def print(message, color)
          puts colorize(message, color)
        end

        private
        
        def seperator
          return (is_windows? ? "\\" : "/")
        end
      end
    end
  end
end
