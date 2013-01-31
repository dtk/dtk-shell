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
  	  			"#{genv(:appdata)}/DTK"
  				else
  	  			# returns log_path for current user e.g /var/log/user1
  	  			"/var/log/dtk/#{::DTK::Common::Aux.running_process_user()}"
  			  end
        end

        def dtk_home_dir
          return "#{home_dir}"
        end

        def dtk_user_app_folder
          return "#{dtk_app_folder}#{::DTK::Common::Aux.running_process_user()}/"
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

        def module_clone_location(module_location)
          return (module_location.start_with?('/') ? module_location : "#{home_dir}/#{module_location}")
        end
        def service_clone_location(service_location)
          return (service_location.start_with?('/') ? service_location : "#{home_dir}/#{service_location}")
        end

        private
        
        def seperator
          return (is_windows? ? "\\" : "/")
        end
      end
    end
  end
end
