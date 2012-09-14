#TODO: user common utils in DTK::Common::Rest

require 'rubygems'
require 'singleton'
require 'restclient'
require 'json'
require 'pp'
#TODO: for testing; fix by pass in commadn line argument
#RestClient.log = STDOUT

dtk_require_from_base('domain/response')


def top_level_execute(command=nil,argv=nil,shell_execute=false)
  begin
    $: << "/usr/lib/ruby/1.8/" #TODO: put in to get around path problem in rvm 1.9.2 environment
    argv ||= ARGV

    include DTK::Client::Aux


    command = command || $0.gsub(Regexp.new("^.+/"),"")
    command = command.gsub("-","_")

    load_command(command)

    conn = DTK::Client::Conn.new()

    # call proper thor class and task
    command_class = DTK::Client.const_get "#{cap_form(command)}"
    response_ruby_obj = command_class.execute_from_cli(conn,argv,shell_execute)

    # check for errors in response
    unless response_ruby_obj["errors"].nil?
      error_internal = false
      error_msg      = response_ruby_obj['errors'].map{|e| e["message"].gsub(/\.$/,"") unless e["message"].nil?}.join(". ")
      error_internal = response_ruby_obj['errors'].map{|e| e["internal"] unless e["internal"].nil?}

      response_ruby_obj["errors"].each do |e|
        error_internal ||= e["internal"]
      end
      
      # if error_internal.first == true
      if error_internal
        # if internal error occured, store details to log
        DtkLogger.instance.error("Response Error Message: #{error_msg}.")
        # and display message to console
        #TODO not sure what message should be displayed, in jirra ticket it said that descriptive error should be printed out
        raise DTK::Client::DtkError, "Server has encountered internal error, please contact DTK team. See error log for more details."
      else
        # if usage error occured, display message to console and display that same message to log
        DtkLogger.instance.error("Usage error occured. Error message: #{error_msg}")
        raise DTK::Client::DtkError, "Usage error occured. Error message: #{error_msg}" 
      end
    end

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

  rescue DTK::Client::DtkError => e
    # this are expected application errors
    puts e.message
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

module DTK
  module Client
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
        self[:component_modules_dir] = "#{ENV["HOME"]}/component_modules"
      end
      CONFIG_FILE = File.expand_path("~/.dtkclient")
      def load_config_file()
        parse_key_value_file(CONFIG_FILE).each{|k,v|self[k]=v}
      end
      REQUIRED_KEYS = [:server_host]
      def validate
        #TODO: need to check for legal values
        missing_keys = REQUIRED_KEYS - keys
        raise DTK::Client::DtkError,"Missing config keys (#{missing_keys.join(",")})" unless missing_keys.empty?
      end
    end

    class Conn
      def initialize()
        @cookies = Hash.new
        @connection_error = nil
        login()
      end
      attr_reader :connection_error

      #######
      def rest_url(route=nil)
        "http://#{Config[:server_host]}:#{Config[:server_port].to_s}/rest/#{route}"
      end

      def get(command_class,url)
        Response.new(command_class,json_parse_if_needed(get_raw(url)))
      end

      def post(command_class,url,body=nil)
        Response.new(command_class,json_parse_if_needed(post_raw(url,body)))
      end

      def connection_error?
        return !@connection_error.nil?
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
        if response.kind_of?(Common::Rest::Response) and not response.ok?
          @connection_error = response
        else
          @cookies = response.cookies
        end
      end
      def get_credentials()
        cred_file = File.expand_path("~/.dtkclient")
        raise DTK::Client::DtkError,"Credential file (#{cred_file}) does not exist" unless File.exists?(cred_file)
        ret = parse_key_value_file(cred_file)
        [:username,:password].each{|k|raise DTK::Client::DtkError,"cannot find #{k}" unless ret[k]}
        ret
      end

      ####
      DefaultRestOpts = {:timeout => 20, :open_timeout => 0.5, :error_response_class => Client::ResponseError}
      def get_raw(url)
        Common::Rest::ClientWrapper.get_raw(url,DefaultRestOpts.merge(:cookies => @cookies))
      end
      def post_raw(url,body)
        Common::Rest::ClientWrapper.post_raw(url,body,DefaultRestOpts.merge(:cookies => @cookies))
      end

      def json_parse_if_needed(item)
        Common::Rest::ClientWrapper.json_parse_if_needed(item)
      end
    end
  end
end
