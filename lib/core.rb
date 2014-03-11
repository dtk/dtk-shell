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

def top_level_execute(entity_name, method_name, context_params=nil, options_args=nil, shell_execute=false)
  begin
    top_level_execute_core(entity_name, method_name, context_params, options_args, shell_execute)
  rescue DTK::Client::DtkLoginRequiredError
    # re-logging user and repeating request
    DTK::Client::OsUtil.print("Session expired: re-establishing session & repeating given task", :yellow)
    DTK::Client::Session.re_initialize()
    top_level_execute_core(entity_name, method_name, context_params, options_args, shell_execute)
  end
end

def top_level_execute_core(entity_name, method_name, context_params=nil, options_args=nil, shell_execute=false)
  extend DTK::Client::OsUtil

  entity_class = nil

  begin
    include DTK::Client::Auxiliary

    entity_name = entity_name.gsub("-","_")
    load_command(entity_name)
    conn = DTK::Client::Session.get_connection()

    # if connection parameters are not set up properly then don't execute any command
    return if validate_connection(conn)
    
    # call proper thor class and task
    entity_class = DTK::Client.const_get "#{cap_form(entity_name)}"

    # call forwarding, in case there is no task for given entity we switch to last (n-context) and try than
    unless (entity_class.task_names.include?(method_name))
      entity_class = DTK::Client.const_get "#{cap_form(context_params.last_entity_name.to_s)}"
    end

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
  rescue DTK::Client::DtkLoginRequiredError => e
    # this error is handled in method above
    raise e
  rescue DTK::Client::DSLParsing => e
    DTK::Client::OsUtil.print(e.message, :red)
  rescue DTK::Client::DtkValidationError => e
    validation_message = e.message
    
    # if !e.skip_usage_info && entity_class && method_name
    #   usage_info = entity_class.get_usage_info(entity_name, method_name)
    #   validation_message += ", usage: #{usage_info}"
    # end

    if e.display_usage_info && entity_class && method_name
      usage_info = entity_class.get_usage_info(entity_name, method_name)
      validation_message += ", usage: #{usage_info}"

      validation_message.gsub!("^^", '') if validation_message.include?("^^")
      validation_message.gsub!("HIDE_FROM_BASE ", '') if validation_message.include?("HIDE_FROM_BASE")
    end

    DTK::Client::OsUtil.print(validation_message, :yellow)
  rescue DTK::Client::DtkError => e
    # this are expected application errors
    DtkLogger.instance.error_pp(e.message, e.backtrace)
  rescue Exception => e
    DtkLogger.instance.fatal_pp("[INTERNAL ERROR] DTK has encountered an error #{e.class}: #{e.message}", e.backtrace)
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

# check if .add_direct_access file exists, if not then add direct access and create .add_direct_access file
def resolve_direct_access(params)
  return if params[:username_exists]

  puts "Adding direct access for current user..."
  # response = DTK::Client::Account.add_access(params[:ssh_key_path])
  response, matched_pub_key, matched_username = DTK::Client::Account.add_key(params[:ssh_key_path])
  
  if !response.ok?
    DTK::Client::OsUtil.print("We were not able to add direct access for current user. #{response.error_message}. In order to properly use dtk-shell you will have to add access manually ('dtk account add-ssh-key').\n", :yellow) 
  elsif matched_pub_key
    # message will be displayed by add key # TODO: Refactor this flow
    DTK::Client::OsUtil.print("Provided SSH PUB key has already been added.", :yellow)
    DTK::Client::Configurator.add_current_user_to_direct_access()
  elsif matched_username
    DTK::Client::OsUtil.print("User with provided name already exists.", :yellow)
  else
    DTK::Client::OsUtil.print("Your SSH PUB key has been successfully added.", :yellow)
    DTK::Client::Configurator.add_current_user_to_direct_access()
  end
  

  response
end

module DTK
  module Client
    class ResponseErrorHandler
      class << self

        def check_for_session_expiried(response_ruby_obj)
          error_code = nil
          if response_ruby_obj && response_ruby_obj['errors']
            response_ruby_obj['errors'].each do |err|
              error_code      = err["code"]||(err["errors"] && err["errors"].first["code"])
            end
          end

          return (error_code == "forbidden")
        end

        def check(response_ruby_obj)
          # check for errors in response
             
          unless response_ruby_obj["errors"].nil?
            error_msg       = ""
            error_internal  = nil
            error_backtrace = nil
            error_code      = nil
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
            error_msg = error_msg.empty? ? 'Internal DTK Client error, please try again' : "#{error_msg}"
            
            # if error_internal.first == true
            if error_code == "unauthorized"
              raise DTK::Client::DtkError, "[UNAUTHORIZED] Your session has been suspended, please log in again."
            elsif error_code == "session_timeout"
              raise DTK::Client::DtkError, "[SESSION TIMEOUT] Your session has been suspended, please log in again."
            elsif error_code == "broken"
              raise DTK::Client::DtkError, "[BROKEN] Unable to connect to the DTK server at host: #{Config[:server_host]}"
            elsif error_code == "forbidden"
              raise DTK::Client::DtkLoginRequiredError, "[FORBIDDEN] Access not granted, please log in again."
            elsif error_code == "timeout"
              raise DTK::Client::DtkError, "[TIMEOUT ERROR] Server is taking too long to respond." 
            elsif error_code == "connection_refused"
              raise DTK::Client::DtkError, "[CONNECTION REFUSED] Connection refused by server."
            elsif error_code == "resource_not_found"
              raise DTK::Client::DtkError, "[RESOURCE NOT FOUND] #{error_msg}"
            elsif error_code == "pg_error"
              raise DTK::Client::DtkError, "[PG_ERROR] #{error_msg}"
            elsif error_internal
              where = (error_on_server ? "SERVER" : "CLIENT")
              #opts = (error_backtrace ? {:backtrace => error_backtrace} : {})
              raise DTK::Client::DtkError.new("[#{where} INTERNAL ERROR] #{error_msg}", :backtrace => error_backtrace)
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
        DTK::Client::Configurator.parse_key_value_file(file)
      end

    end
    class Config < Hash
      include Singleton
      include ParseFile
      dtk_require_from_base('configurator')

      CONFIG_FILE = ::DTK::Client::Configurator.CONFIG_FILE
      CRED_FILE = ::DTK::Client::Configurator.CRED_FILE
      
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


    ##
    # Session Singleton we will use to hold connection instance, just a singleton wrapper.
    # During shell input it will be needed only once, so singleton was obvious solution.
    #
    class Session
      include Singleton

      attr_accessor :conn

      def initialize()
        @conn = DTK::Client::Conn.new()
      end

      def self.get_connection()
        Session.instance.conn
      end

      def self.re_initialize()
        Session.instance.conn = nil
        Session.instance.conn = DTK::Client::Conn.new()
        Session.instance.conn.cookies
      end

      def self.logout()
        # from this point @conn is not valid, since there are no cookies set
        Session.instance.conn.logout()
      end
    end

    class Conn
      def initialize()
        @cookies = Hash.new
        @connection_error = nil
        login()
      end

      VERBOSE_MODE_ON = ::DTK::Configuration.get(:verbose_rest_calls)

      attr_reader :connection_error, :cookies

      if VERBOSE_MODE_ON
        require 'ap'
      end

      def self.get_timeout()
        DefaultRestOpts[:timeout]
      end

      def self.set_timeout(timeout_sec)
        DefaultRestOpts[:timeout] = timeout_sec
      end
               

      def rest_url(route=nil)
        protocol, port = "http", Config[:server_port].to_s
        protocol, port = "https", Config[:secure_connection_server_port].to_s if Config[:secure_connection] == "true"
        
        "#{protocol}://#{Config[:server_host]}:#{port}/rest/#{route}"
      end

      def get(command_class,url)
        ap "GET #{url}" if VERBOSE_MODE_ON

        check_and_wrap_response(command_class, Proc.new { json_parse_if_needed(get_raw(url)) })
      end

      def post(command_class,url,body=nil)
        if VERBOSE_MODE_ON
          ap "POST (REST) #{url}"
          ap "params: "
          ap body
        end

        check_and_wrap_response(command_class, Proc.new { json_parse_if_needed(post_raw(url,body)) })
      end

      def post_file(command_class,url,body=nil)
        if VERBOSE_MODE_ON
          ap "POST (FILE) #{url}"
          ap "params: "
          ap body
        end

        check_and_wrap_response(command_class, Proc.new { json_parse_if_needed(post_raw(url,body,{:content_type => 'avro/binary'})) })
      end

      # method will repeat request in case session has expired
      def check_and_wrap_response(command_class, rest_method_func)
        response = rest_method_func.call

        if ResponseErrorHandler.check_for_session_expiried(response)
          # re-logging user and repeating request
          DTK::Client::OsUtil.print("Session expired: re-establishing session & re-trying request ...", :yellow)
          @cookies = DTK::Client::Session.re_initialize()
          response = rest_method_func.call
        end

        Response.new(command_class, response)
      end



      def connection_error?
        return !@connection_error.nil?
      end

      def logout()
        response = get_raw rest_url("user/process_logout")

        # save cookies - no need to persist them
        # DiskCacher.new.save_cookie(@cookies)

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
        printf "%15s %s\n", "Password:", "#{creds[:password] ? creds[:password].gsub(/./,'*') : 'No password set'}"
        puts   "==================================================================="
        error_code = self.connection_error['errors'].first['errors'].first['code']
        print " Error code: "
        DTK::Client::OsUtil.print(error_code, :red)

      end

      private

      include ParseFile

      def login()
        creds = get_credentials()
        response = post_raw rest_url("user/process_login"),creds
        errors = response['errors']

        if response.kind_of?(Common::Response) and not response.ok?    
          puts errors.first['code']
          if (errors && errors.first['code']=="pg_error")
            DTK::Client::OsUtil.print(errors.first['message'].gsub!("403 Forbidden", "[PG_ERROR]"), :red)
            exit
          end
          @connection_error = response
        else
          @cookies = response.cookies
        end
      end

      def get_credentials()
        cred_file = Config::CRED_FILE
        raise DTK::Client::DtkError,"Authorization configuration file (#{cred_file}) does not exist" unless File.exists?(cred_file)
        ret = parse_key_value_file(cred_file)
        [:username,:password].each{|k|raise DTK::Client::DtkError,"cannot find #{k}" unless ret[k]}
        ret
      end

      ####
      RestClientWrapper = Common::Response::RestClientWrapper

      # In development mode we want bigger timeout allowing us to debbug on server while still
      # keeping connection alive and receivinga response
      if ::DTK::Configuration.get(:development_mode)
        DefaultRestOpts = {:timeout => 2000, :open_timeout => 2, :error_response_class => Client::Response::Error}
        # DefaultRestOpts = {:timeout => 50, :open_timeout => 2, :error_response_class => Client::Response::Error}
      else
        DefaultRestOpts = {:timeout => 100, :open_timeout => 1, :error_response_class => Client::Response::Error}
      end

      # enable SSL verification
      DefaultRestOpts.merge!(:verify_ssl => OpenSSL::SSL::VERIFY_PEER)
      # Net:HTTP from Ruby 1.8.7 doesn't verify SSL certs correctly
      # this is a CA bundle downloaded from http://curl.haxx.se/docs/caextract.html, 
      # and it will only be used for 1.8.7, otherwise the default (system) CA will be used
      DefaultRestOpts.merge!(:ssl_ca_file => File.expand_path('../lib/config/cacert.pem', File.dirname(__FILE__)))
    
      def get_raw(url)
        RestClientWrapper.get_raw(url, {}, DefaultRestOpts.merge(:cookies => @cookies))
      end
      def post_raw(url,body,params={})
        RestClientWrapper.post_raw(url, body, DefaultRestOpts.merge(:cookies => @cookies).merge(params))
      end

      def json_parse_if_needed(item)
        RestClientWrapper.json_parse_if_needed(item)
      end
    end
  end
end
