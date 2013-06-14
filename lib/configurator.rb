require 'rubygems'

dtk_require_from_base('util/os_util')

module DTK
	module Client
		class Configurator

			CONFIG_FILE = File.join(OsUtil.dtk_local_folder, "client.conf")
	    CRED_FILE = File.join(OsUtil.dtk_local_folder, ".connection")

			require 'fileutils'
			FileUtils.mkdir(OsUtil.dtk_local_folder) if !File.directory?(OsUtil.dtk_local_folder)

	    def self.CONFIG_FILE
	    	CONFIG_FILE
	    end

	    def self.CRED_FILE
	    	CRED_FILE
	    end

			def self.check_config_exists
				if !File.exists?(CONFIG_FILE)
					puts "", "Please enter the DTK server address (example: dtk.r8network.com)"
					header = File.read(File.expand_path('../lib/config/client.conf.header', File.dirname(__FILE__)))
					generate_conf_file(CONFIG_FILE, [['server_host', 'Server address']], header)
				end
				if !File.exists?(CRED_FILE)
					puts "", "Please enter your DTK login details"
					generate_conf_file(CRED_FILE, [['username', 'Username'], ['password', 'Password']], '')
				end
			end

			def self.check_git
				if OsUtil.is_linux? || OsUtil.is_mac?
					if OsUtil.which('git') == nil
						puts "[WARNING] Can't find the 'git' command in you path. Please make sure git is installed in order to use all features of DTK Client."
					else
						puts '[WARNING] Git username not set. This can cause issues while using DTK Client. To set it, run `git config --global user.name "User Name"`' if `git config --get user.name` == ""
						puts '[WARNING] Git email not set. This can cause issues while using DTK Client. To set it, run `git config --global user.email "me@here.com"`' if `git config --get user.email` == ""
					end
				end
			end


			def self.generate_conf_file(file_path, properties, header)
				require 'highline/import'
				property_template = []
				
					properties.each do |p,d|
						begin
							trap("INT") { 
								puts "", "Exiting..."
								abort 
							}
						end
						value = ask("#{d}: ") { |q| q.echo = false if p == 'password'}
						property_template << [p,value]
					end

				File.open(file_path, 'w') do |f|
					f.puts(header)
					property_template.each do |prop|
						f.puts("#{prop[0]}=#{prop[1]}")
					end
				end

			end

		end
	end
end

