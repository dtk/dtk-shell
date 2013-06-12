dtk_require_from_base('util/os_util')

module DTK
	module Client
		class Configurator

			CONFIG_FILE = File.join(OsUtil.dtk_local_folder, "client.conf")
	    CRED_FILE = File.join(OsUtil.dtk_local_folder, ".connection")

	    def self.CONFIG_FILE
	    	CONFIG_FILE
	    end

	    def self.CRED_FILE
	    	CRED_FILE
	    end

			def self.check_config_exists
				generate_config_file if !File.exists?(CONFIG_FILE)
				generate_cred_file if !File.exists?(CRED_FILE)
			end

			def self.generate_cred_file
				puts "#{CRED_FILE} is missing."
				generate_conf_file(CRED_FILE, ['username', 'password'], '')
			end

			def self.generate_config_file
				puts "#{CONFIG_FILE} is missing."
				header = File.read(File.expand_path('../lib/config/client.conf.header', File.dirname(__FILE__)))
			end

			def self.generate_conf_file(file_path, properties, header)
				property_template = []
				properties.each do |p|
					puts "Enter your #{p}:"
					value = gets.chomp
					property_template << [p,value]
				end

				require 'rubygems'
				require 'awesome_print'

				ap property_template

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

