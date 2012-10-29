dtk_require_from_base('domain/response')

module DTK
  module Client
    module OsUtil
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
        is_windows? ? ENV['TEMP'] : '/tmp'
      end

      def get_log_location
        if is_windows?
	  			"#{ENV['APPDATA']}\\DTK"
				else
	  			# returns log_path for current user e.g /var/log/user1
	  			"/var/log/dtk/#{Common::Aux.running_process_user()}"
				end
      end

      def dtk_home_dir
        return "#{home_dir}dtk"
      end

      def home_dir
        return (is_windows? ? "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}\\" : "#{ENV['HOME'"']}/")
      end

      def module_clone_location(module_location)
        return (module_location.start_with?('/') ? module_location : "#{home_dir}#{module_location}")
      end

      private

      def seperator
        return (is_windows? ? "\\" : "/")
      end
    end
  end
end
