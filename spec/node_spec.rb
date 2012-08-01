require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","node")
include SpecThor

describe DTK::Client::Node do

  # generic test for all task of Thor class
  test_task_interface(DTK::Client::Node)

end
