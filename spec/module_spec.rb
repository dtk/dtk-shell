require 'lib/spec_thor'

dtk_nested_require("../lib/commands/thor","module")

include SpecThor

describe DTK::Client::Module do

  # generic test for all task of Thor class
  test_task_interface(DTK::Client::Module)

end
