require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","target")
include SpecThor

describe DTK::Client::Target do

  # generic test for all task of Thor class
  test_task_interface(DTK::Client::Target)

end

