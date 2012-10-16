module DTK
  module Client
    module OsUtil
      def is_mac?
        RUBY_PLATFORM.downcase.include?('darwin')
      end

      def is_windows?
        RUBY_PLATFORM.downcase.include?('mswin')
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

      def get_home_dir
        if is_windows?
          "#{ENV(HOMEDRIVE)}#{ENV(HOMEPATH)}\\dtk"
        else
          File.expand_path('~/dtk')
        end
      end
      
    end
  end
end
