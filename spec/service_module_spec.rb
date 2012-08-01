require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","service_module")
include SpecThor

describe DTK::Client::ServiceModule do

  # generic test for all task of Thor class
  test_task_interface(DTK::Client::ServiceModule)

end

