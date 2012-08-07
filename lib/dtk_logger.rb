##
# DtkLogger singleton to be used for logging.
#
require 'singleton'
require 'logger'

class DtkLogger

  #
  LOG_FILE_NAME                = 'dtk-client.log'
  LOG_MB_SIZE             = 2
  LOG_NUMBER_OF_OLD_FILES = 10

  include Singleton

  def initialize
    home_dir = `cd ~;pwd`.chomp
    file = File.open("#{home_dir}/#{LOG_FILE_NAME}", "a")
    @logger = Logger.new(file, LOG_NUMBER_OF_OLD_FILES, LOG_MB_SIZE * 1024000)
  end

  def debug(log_text, sttdout_out=false)
    puts log_text if sttdout_out
    @logger.debug(log_text)
  end

  def info(log_text, sttdout_out=false)
    puts log_text if sttdout_out
    @logger.info(log_text)
  end

  def warn(log_text, sttdout_out=false)
    puts log_text if sttdout_out
    @logger.warn(log_text)
  end

  def error(log_text, sttdout_out=false)
    puts log_text if sttdout_out
    @logger.error(log_text)
  end

  def fatal(log_text, sttdout_out=false)
    puts log_text if sttdout_out
    @logger.fatal(log_text)
  end

  def logger
    @logger
  end
end