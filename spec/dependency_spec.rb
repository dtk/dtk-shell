require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","dependency")
include SpecThor

describe DTK::Client::Dependency do

  # generic test for all task of Thor class
  test_task_interface(DTK::Client::Dependency)

end

