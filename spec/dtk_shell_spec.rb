require File.expand_path('../lib/shell',                   File.dirname(__FILE__))
require 'ap'

describe DTK::Shell do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Task)

  init_shell_context()

  line = 'cc /assembly'
  execute_shell_command(line,'')

end