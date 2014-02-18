require File.expand_path('../lib/shell',                   File.dirname(__FILE__))

describe DTK::Shell do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Task)

  init_shell_context()

  line = 'cc /service'
  execute_shell_command(line,'')

end
