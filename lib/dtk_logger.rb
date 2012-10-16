##
# DtkLogger singleton to be used for logging.
#
require 'singleton'
require 'logger'
require File.expand_path('./util/os_util', File.dirname(__FILE__))

class DtkLogger

  #
  LOG_FILE_NAME           = 'client.log'
  LOG_MB_SIZE             = 2
  LOG_NUMBER_OF_OLD_FILES = 10
  DEVELOPMENT_MODE        = Config::Configuration.get(:development_mode)

  include Singleton
  include DTK::Client::OsUtil

  def initialize
    log_location_dir = get_log_location()
    begin
      if File.directory?(log_location_dir)
        file = File.open("#{get_log_location()}/#{LOG_FILE_NAME}", "a")
        @logger = Logger.new(file, LOG_NUMBER_OF_OLD_FILES, LOG_MB_SIZE * 1024000)
        
        @logger.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime}] #{severity} -- : #{msg}\n"
        end
      else
        no_log_dir(log_location_dir)
      end
     rescue Errno::EACCES
      no_log_permissions(log_location_dir)
    end
  end

  def debug(log_text, sttdout_out=false)
    puts log_text if sttdout_out || DEVELOPMENT_MODE
    @logger.debug(log_text) if log_created?
  end

  def info(log_text, sttdout_out=false)
    puts log_text if sttdout_out || DEVELOPMENT_MODE
    @logger.info(log_text) if log_created?
  end

  def warn(log_text, sttdout_out=false)
    puts log_text if sttdout_out || DEVELOPMENT_MODE
    @logger.warn(log_text) if log_created?
  end

  def error(log_text, sttdout_out=false)
    puts log_text if sttdout_out || DEVELOPMENT_MODE
    @logger.error(log_text) if log_created?
  end

  def fatal(log_text, sttdout_out=false)
    puts log_text if sttdout_out || DEVELOPMENT_MODE
    @logger.fatal(log_text) if log_created?
  end

  private

  def log_created?
    #no log found if @logger.nil?
    return !@logger.nil?
  end

  def no_log_dir(dir)
    puts "[WARNING] Log directory (#{dir}) does not exist; please add it manually or re-install DTK client."
  end

  def no_log_permissions(dir)
    puts "[WARNING] User (#{DTK::Common::Aux.running_process_user()}) does not have permissions to create a log file in log directory (#{dir})"
  end
end
