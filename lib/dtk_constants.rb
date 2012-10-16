require 'singleton'
dtk_require("config/disk_cacher")

class PPColumns

  include Singleton

  def initialize
    content = DiskCacher.new.fetch("http://localhost/mockup/get_const_metadata", ::Config::Configuration.get(:meta_constants_ttl))
    raise DTK::Client::DtkError, "Require constants metadata is empty, please contact DTK team." if content.empty?
    @constants = JSON.parse(content)
  end

  def self.get(symbol_identifier)
    return PPColumns.instance.get(symbol_identifier)
  end

  def get(symbol_identifier)
    return @constants[symbol_identifier.to_s]
  end

end
