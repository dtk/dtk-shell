require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","task")
include SpecThor

describe DTK::Client::Task do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Task)

  context "#list" do
  	command = "dtk task list"
  	output  = `#{command}`

  	it "should list all tasks" do
  		output.should match(/(task|empty|error)/)
  	end
  end

end