#
# Singleton patern to hold configuration for dtk client.
#
# DEFAULT:     Production configuration 
# DEVELOPMENT: Can add lib/config/local_configuration.yml, this is git ignored
#
# NOTE: Singleton here is not necessery since it will not persist in memory due
#       to nature of DTK Client, but it is right approach for possible re-use
#
require 'singleton'

module Config
  class Configuration
    include Singleton

    DEVELOPMENT_CONF = 'local_configuration.yml'
    PRODUCTION_CONF  = 'production_configuration.yml'

    def self.get(group, name, default=nil)
      Configuration.instance.get(group, name, default)
    end
    
    def initialize
      @cache = YAML::load_file(File.expand_path("../#{PRODUCTION_CONF}",__FILE__))

      if File.exist?(File.expand_path("../#{DEVELOPMENT_CONF}",__FILE__))
        local_configuration = YAML::load_file(File.expand_path("../#{DEVELOPMENT_CONF}",__FILE__))
        # we override only values from local configuration
        # that way developer does not have updates its local configuration all the time
        @cache.merge!(local_configuration)
      end

    end

    def get(group, name, default=nil)
      return @cache[group.to_s][name.to_s] || default
    end

  end
end