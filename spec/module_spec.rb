require 'lib/spec_thor'

dtk_nested_require("../lib/commands/thor","module")

include SpecThor

describe DTK::Client::Module do

  # generic test for all task of Thor class
  test_task_interface(DTK::Client::Module)

  #TODO when dtk module list is implemented to work properly 
  context "#list" do
  end

end
