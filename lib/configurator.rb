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
			end

			def self.generate_config_file
				puts "#{CONFIG_FILE} is missing."
			end

		end
	end
end

