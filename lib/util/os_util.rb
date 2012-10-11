require 'etc'

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
				if is_windows?
					return ENV['TEMP']
				else
					return '/tmp'
				end
			end

			def get_log_location
				if is_windows?
					return "#{ENV['APPDATA']}\\DTK"
				else
					# returns log_path for current user e.g /var/log/user1
					return "/var/log/#{Etc.getlogin}"
				end
			end

			private

			def create_user_log_folder(current_user)

			end

			def user_log_folder_exist?(current_user)
				return File.directory?("/var/log/#{current_user}")
			end

		end
	end
end