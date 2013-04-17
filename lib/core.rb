#TODO: user common utils in DTK::Common::Rest

require 'rubygems'
require 'singleton'
require 'restclient'
require 'colorize'
require 'json'
require 'pp'
#TODO: for testing; fix by pass in commadn line argument
#RestClient.log = STDOUT

dtk_require_from_base('domain/response')
dtk_require_from_base('util/os_util')
dtk_require("config/configuration")

def top_level_execute(entity_name, method_name, context_params=nil,options_args=nil,shell_execute=false)
  extend DTK::Client::OsUtil
  begin
    include DTK::Client::Auxiliary

    entity_name = entity_name.gsub("-","_")
    load_command(entity_name)
    conn = DTK::Client::Session.get_connection()

    # if connection parameters are not set up properly then don't execute any command
    return if validate_connection(conn)

    # call proper thor class and task
    entity_class = DTK::Client.const_get "#{cap_form(entity_name)}"
    response_ruby_obj = entity_class.execute_from_cli(conn,method_name,context_params,options_args,shell_execute)
    
    # this will raise error if found
    DTK::Client::ResponseErrorHandler.check(response_ruby_obj)

    # this will find appropriate render adapter and give output, returns boolean
    if print = response_ruby_obj.render_data() 
      print = [print] unless print.kind_of?(Array)
      print.each do |el|

        if el.kind_of?(String)
          el.each_line{|l| STDOUT << l}
        else
          PP.pp(el,STDOUT)
        end
      end
    end
  rescue DTK::Client::DtkValidationError => e
    DTK::Client::OsUtil.print(e.message, :yellow)
  rescue DTK::Client::DtkError => e
    # this are expected application errors
    DTK::Client::OsUtil.print(e.message, :red)
    DtkLogger.instance.error(e.message)
    if e.backtrace
      puts e.backtrace
    end
  rescue Exception => e
    # All errors for task will be handled here
    DtkLogger.instance.fatal("[INTERNAL ERROR] DTK has encountered an error #{e.class}: #{e.message}",true)
    DtkLogger.instance.fatal(e.backtrace)
    puts e.backtrace
  end
end

def load_command(command_name)
  parser_adapter = DTK::Client::Config[:cli_parser] || "thor"

  dtk_nested_require("parser/adapters",parser_adapter)
  dtk_nested_require("commands/#{parser_adapter}",command_name)
end

# check if connection is set up properly
def validate_connection(connection)
  if connection.connection_error?
    connection.print_warning
    puts "\nDTK will now exit. Please set up your connection properly and try again."
    return true
  end
end

module DTK
  module Client
    class ResponseErrorHandler
      class << self
        def check(response_ruby_obj)
          # check for errors in response
          unless response_ruby_obj["errors"].nil?

            error_msg       = ""
            error_internal  = nil
            error_backtrace = nil
            error_code      = nil
            error_timeout   = nil
            error_on_server = nil
            #TODO:  below just 'captures' first error
            response_ruby_obj['errors'].each do |err|
              error_msg       +=  err["message"] unless err["message"].nil?
              error_msg       +=  err["error"]   unless err["error"].nil?
              error_on_server = true unless err["on_client"]
              error_code      = err["code"]||(err["errors"] && err["errors"].first["code"])
              error_internal  ||= (err["internal"] or error_code == "not_found") #"not_found" code is at Ramaze level; so error_internal not set
              error_backtrace ||= err["backtrace"]
            end
            
            # normalize it for display
            error_msg = error_msg.empty? ? 'No error description found' : "#{error_msg}"
            
            # if error_internal.first == true
            if error_code == "unauthorized"
              raise DTK::Client::DtkError, "[UNAUTHORIZED] Your session has been suspended, please log in again."
            elsif error_code == "forbidden"
              raise DTK::Client::DtkError, "[FORBIDDEN] Access not granted, please log in again."
            elsif error_code == "timeout"
              raise DTK::Client::DtkError, "[TIMEOUT ERROR] Server is taking too long to respond." 
            elsif error_code == "connection_refused"
              raise DTK::Client::DtkError, "[CONNECTION REFUSED] Connection refused by server." 
            elsif error_internal
              where = (error_on_server ? "SERVER" : "CLIENT")
              opts = (error_backtrace ? {:backtrace => error_backtrace} : {})
              raise DTK::Client::DtkError.new("[#{where} INTERNAL ERROR] #{error_msg}",opts)
            else
              # if usage error occurred, display message to console and display that same message to log
              raise DTK::Client::DtkError, "[ERROR] #{error_msg}." 
            end
          end
        end
      end
    end


    class Log
      #TODO Stubs
      def self.info(msg)
        pp "info: #{msg}"
      end
      def self.error(msg)
        pp "error: #{msg}"
      end
    end

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
    class Config < Hash
      include Singleton
      include ParseFile

      CONFIG_FILE = File.join(OsUtil.dtk_home_dir, ".dtkclient")
      REQUIRED_KEYS = [:server_host]

      def self.[](k)
        Config.instance[k]
      end
     private
      def initialize()
        set_defaults()
        load_config_file()
        validate()
      end
      def set_defaults()
        self[:server_port] = 7000
        self[:component_modules_dir] = OsUtil.module_clone_location()
        self[:service_modules_dir] = OsUtil.service_clone_location()
        self[:secure_connection] = true
        self[:secure_connection_server_port] = 7002
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


    ##
    # Session Singleton we will use to hold connection instance, just a singleton wrapper.
    # During shell input it will be needed only once, so singleton was obvious solution.
    #
    class Session
      include Singleton

      attr_reader :conn

      def initialize()
        @conn = DTK::Client::Conn.new()
      end

      def self.get_connection()
        Session.instance.conn
      end

      def self.logout()
        # from this point @conn is not valid, since there are no cookies set
        Session.instance.conn.logout()
      end
    end

    class Conn
      def initialize()
        #@cookies = DiskCacher.new.load_cookie
        @cookies = Hash.new
        @connection_error = nil
        login()
      end

      VERBOSE_MODE_ON = ::Config::Configuration.get(:verbose_rest_calls)

      attr_reader :connection_error

      if VERBOSE_MODE_ON
        require 'ap'
      end
               

      def rest_url(route=nil)
        protocol, port = "http", Config[:server_port].to_s
        protocol, port = "https", Config[:secure_connection_server_port].to_s if Config[:secure_connection] == "true"
        
        "#{protocol}://#{Config[:server_host]}:#{port}/rest/#{route}"
      end

      def get(command_class,url)
        ap "GET #{url}" if VERBOSE_MODE_ON
        Response.new(command_class,json_parse_if_needed(get_raw(url)))
      end

      def post(command_class,url,body=nil)
        if VERBOSE_MODE_ON
          ap "POST (REST) #{url}"
          ap "params: "
          ap body
        end
        Response.new(command_class,json_parse_if_needed(post_raw(url,body)))
      end

      def post_file(command_class,url,body=nil)
        if VERBOSE_MODE_ON
          ap "POST (FILE) #{url}"
          ap "params: "
          ap body
        end
        Response.new(command_class,json_parse_if_needed(post_raw(url,body,{:content_type => 'avro/binary'})))
      end

      def connection_error?
        return !@connection_error.nil?
      end

      def logout()
        response = get_raw rest_url("user/process_logout")

        # save cookies
        #DiskCacher.new.save_cookie(@cookies)

        raise DTK::Client::DtkError, "Failed to logout, and terminate session!" unless response
        @cookies = nil
      end

      ##
      # Method will warn user that connection could not be established. User should check configuration
      # to make sure that connection is properly set.
      #
      def print_warning
        puts   "[WARNING] Unable to connect to server, please check you configuration."
        puts   "========================== Configuration =========================="
        printf "%15s %s\n", "REST endpoint:", rest_url
        creds = get_credentials
        printf "%15s %s\n", "Username:", "#{creds[:username]}"
        printf "%15s %s\n", "Password:", "#{creds[:password]}"
        puts   "==================================================================="
      end

      private
      include ParseFile
      def login()
        creds = get_credentials()
        response = post_raw rest_url("user/process_login"),creds
        if response.kind_of?(Common::Response) and not response.ok?
          @connection_error = response
        else
          @cookies = response.cookies
        end
      end

      def get_credentials()
        cred_file = Config::CONFIG_FILE
        raise DTK::Client::DtkError,"Authorization configuration file (#{cred_file}) does not exist" unless File.exists?(cred_file)
        ret = parse_key_value_file(cred_file)
        [:username,:password].each{|k|raise DTK::Client::DtkError,"cannot find #{k}" unless ret[k]}
        ret
      end

      ####
      RestClientWrapper = Common::Response::RestClientWrapper
      DefaultRestOpts = {:timeout => 20, :open_timeout => 0.5, :error_response_class => Client::Response::Error}

      def get_raw(url)
        RestClientWrapper.get_raw(url,DefaultRestOpts.merge(:cookies => @cookies))
      end
      def post_raw(url,body,params={})
        RestClientWrapper.post_raw(url,body,DefaultRestOpts.merge(:cookies => @cookies).merge(params))
      end

      def json_parse_if_needed(item)
        RestClientWrapper.json_parse_if_needed(item)
      end
    end
  end
end
