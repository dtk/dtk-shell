require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","library")
include SpecThor

describe DTK::Client::Library do

  # generic test for all task of Thor class
  test_task_interface(DTK::Client::Library)

end
