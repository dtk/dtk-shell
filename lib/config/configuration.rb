#
# Singleton patern to hold configuration for dtk client.
#
# DEFAULT:     Configuration 
# DEVELOPMENT: Can add lib/config/local.conf, this is git ignored
#
# NOTE: Singleton here is not necessery since it will not persist in memory due
#       to nature of DTK Client, but it is right approach for possible re-use
#
# Pririoty of load
#   1) LOCAL
#   2) EXTERNAL
#   3) DEFAULT
#
# NOTE: Default will be used if there some parameters missing in other configuration
#
require 'singleton'

dtk_require_from_base('configurator')
dtk_require_from_base('util/os_util')

module DTK
  module ParseFile
    def parse_key_value_file(file)
      #adapted from mcollective config
      ret = Hash.new
      raise DTK::Client::DtkError,"Config file (#{file}) does not exists" unless File.exists?(file)
      File.open(file).each do |line|
        # strip blank spaces, tabs etc off the end of all lines
        line.gsub!(/\s*$/, "")
        unless line =~ /^#|^$/
          if (line =~ /(.+?)\s*=\s*(.+)/)
            key = $1
            val = $2
            ret[key.to_sym] = val
          end
        end
      end
      ret
    end
  end

  class Configuration < Hash
    include Singleton
    include ParseFile    

    EXTERNAL_APP_CONF = "client.conf"
    DEVELOPMENT_CONF  = 'local.conf'
    DEFAULT_CONF      = 'default.conf'

    CONFIG_FILE = ::DTK::Client::Configurator.CONFIG_FILE
    CRED_FILE = ::DTK::Client::Configurator.CRED_FILE
    
    REQUIRED_KEYS = [:server_host]

    def self.get(name, default=nil)
      Configuration.instance.get(name, default)
    end

    def self.[](k)
      Configuration.instance.get(k)
    end
    
    def initialize
      # default configuration
      @cache = load_configuration_to_hash(File.expand_path("../#{DEFAULT_CONF}",__FILE__))

      # we will not use local.conf from gemfile because client.conf is required so this is deprecated
      if File.exist?(File.expand_path("../#{DEVELOPMENT_CONF}",__FILE__))
        local_configuration = load_configuration_to_hash(File.expand_path("../#{DEVELOPMENT_CONF}",__FILE__))
        # we override only values from local configuration
        # that way developer does not have updates its local configuration all the time
        @cache.merge!(local_configuration)
        # if we have loaded local configuration we will not check external
        return
      end

      # We load this if there is no local configuration
      external_file_location = File.join(::DTK::Client::OsUtil.dtk_local_folder(), "#{EXTERNAL_APP_CONF}")

      if File.exist?(external_file_location)
        external_configuration = load_configuration_to_hash(external_file_location)
        @cache.merge!(external_configuration)
      end

      set_defaults()
      load_config_file()
      validate()
    end

    def get(name, default=nil)
      return @cache[name.to_s] || default
    end

    private

    def load_configuration_to_hash(path_to_file)
      configuration = Hash[*File.read(path_to_file).gsub(/#.+/,'').strip().gsub(/( |\t)+$/,'').split(/[=\n]+/)]
      # check for types
      return configuration.each do |k,v|
        case v
          when /^(true|false)$/ 
            configuration[k] = v.eql?('true') ? true : false
          when /^[0-9]+$/
            configuration[k] = v.to_i
          when /^[0-9\.]+$/
            configuration[k] = v.to_f
        end
      end
    end

    def set_defaults()
      self[:server_port] = 80
      self[:assembly_module_base_location] = 'assemblies'
      self[:secure_connection] = true
      self[:secure_connection_server_port] = 443
    end

    def load_config_file()
      parse_key_value_file(CONFIG_FILE).each{|k,v|self[k]=v}           
    end
    
    def validate
      #TODO: need to check for legal values
      missing_keys = REQUIRED_KEYS - keys
      raise DTK::Client::DtkError,"Missing config keys (#{missing_keys.join(",")}). Please check your configuration file #{CONFIG_FILE} for required keys!" unless missing_keys.empty?
    end
  end
end
