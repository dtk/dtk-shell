require 'net/http'
#require 'md5' => Ruby 1.8.7 specific
require File.expand_path('../util/os_util', File.dirname(__FILE__))
dtk_require("../commands")


#
# Class dedicated for caching data on local system as well as for cookie management
#
class DiskCacher
  include DTK::Client::CommandBase
  extend DTK::Client::CommandBase

  # file name to hold cookies
  COOKIE_HOLDER_NAME = 'tempdtkstore'

  def initialize(cache_dir=DTK::Client::OsUtil.get_temp_location())
    @cache_dir = cache_dir
  end

  def fetch(file_name, max_age=0, use_mock_up=true)
    file = Digest::MD5.hexdigest(file_name)
    file_path = File.join(@cache_dir, file)

    # we check if the file -- a MD5 hexdigest of the URL -- exists
    #  in the dir. If it does and the data is fresh, we just read
    #  data from the file and return
    if File.exists? file_path
      return File.new(file_path).read if Time.now-File.mtime(file_path)<max_age
    end

    # if the file does not exist (or if the data is not fresh), we
    #  make an get request and save it to a file
    response_string = ""
    @response = get rest_url("metadata/get_metadata/#{file_name}")

    if (@response["status"] == "ok")
      file = File.open(file_path, "w") do |data|
        data << response_string = @response["data"]
      end
    end

    return response_string
  end

  def save_cookie(cookie_content)
    file_path = File.join(@cache_dir, COOKIE_HOLDER_NAME)
    File.open(file_path, "w") do |file|
      #data <<  cookie_content
      Marshal.dump(cookie_content, file)
    end
  end

  def load_cookie()
    file_path = File.join(@cache_dir, COOKIE_HOLDER_NAME)
    cookie_content = File.exists?(file_path) ? File.open(file_path) {|f| Marshal.load(f)} : nil
    cookie_content
  end

end