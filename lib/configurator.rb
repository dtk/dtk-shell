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

