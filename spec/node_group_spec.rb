require 'lib/spec_thor'

dtk_nested_require("../lib/commands/thor","node_group")

include SpecThor

describe DTK::Client::NodeGroup do

  # generic test for all task of Thor class
  test_task_interface(DTK::Client::NodeGroup)

end
