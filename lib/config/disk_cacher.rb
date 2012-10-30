require 'net/http'
require 'md5'
require 'fakeweb'
require File.expand_path('../util/os_util', File.dirname(__FILE__))

class DiskCacher

  include DTK::Client::OsUtil

  def initialize(cache_dir=get_temp_location)
    # this is the dir where we store our cache
    @cache_dir = cache_dir
  end
  def fetch(url, max_age=0, use_mock_up=true)
    file = MD5.hexdigest(url)
    file_path = File.join(@cache_dir, file)

    # TODO: Remove this
    if use_mock_up
      FakeWeb.register_uri(:get, "http://localhost/mockup/get_table_metadata", :body => File.open(File.expand_path('../../meta-response.json',File.dirname(__FILE__)),'rb').read)
      FakeWeb.register_uri(:get, "http://localhost/mockup/get_const_metadata", :body => File.open(File.expand_path('../../meta-constants-response.json',File.dirname(__FILE__)),'rb').read)
      FakeWeb.register_uri(:get, "http://localhost/mockup/get_pp_metadata",    :body => File.open(File.expand_path('../../meta-pretty-print-response.json',File.dirname(__FILE__)),'rb').read)
    end

    # we check if the file -- a MD5 hexdigest of the URL -- exists
    #  in the dir. If it does and the data is fresh, we just read
    #  data from the file and return
    if File.exists? file_path
      return File.new(file_path).read if Time.now-File.mtime(file_path)<max_age
    end

    # if the file does not exist (or if the data is not fresh), we
    #  make an HTTP request and save it to a file
    response_string = ""

    file = File.open(file_path, "w") do |data|
      data << response_string=Net::HTTP.get_response(URI.parse(url)).body
    end

    return response_string
  end
end