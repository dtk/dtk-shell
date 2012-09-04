##
# DtkLogger singleton to be used for logging.
#
require 'singleton'
require 'logger'

class DtkLogger

  #
  LOG_FILE_NAME           = 'dtk-client.log'
  LOG_MB_SIZE             = 2
  LOG_NUMBER_OF_OLD_FILES = 10
  DEVELOPMENT_MODE        = false

  include Singleton

  def initialize
    begin
      home_dir = `cd ~;pwd`.chomp
      file = File.open("/var/log/#{LOG_FILE_NAME}", "a")
      @logger = Logger.new(file, LOG_NUMBER_OF_OLD_FILES, LOG_MB_SIZE * 1024000)

    rescue SystemCallError => e
      no_log_found
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
    #no_log_found if @logger.nil?
    return !@logger.nil?
  end

  def no_log_found
    puts "[WARNING] Log file cannot be found please created it yourself or re-install DTK client. Use: 'sudo touch /var/log/#{LOG_FILE_NAME}; sudo chmod 666 /var/log/#{LOG_FILE_NAME}' "
  end

end
