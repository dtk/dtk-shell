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

dtk_require_from_base('util/os_util')

module DTK
  class Configuration
    include Singleton

    EXTERNAL_APP_CONF = "client.conf"
    DEVELOPMENT_CONF  = 'local.conf'
    DEFAULT_CONF      = 'default.conf'

    def self.get(name, default=nil)
      Configuration.instance.get(name, default)
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
      else 
        puts "[INFO] DTK client using default configuration, to override this create your own configuration: #{external_file_location}"
      end

    end

    def get(name, default=nil)
      return @cache[name.to_s] || default
    end

    private

    def load_configuration_to_hash(path_to_file)
      configuration = Hash[*File.read(path_to_file).gsub(/#.+/,'').gsub(/( |\t)+$/,'').split(/[=\n]+/)]
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

  end
end
