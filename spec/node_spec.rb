require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","node")
include SpecThor

describe DTK::Client::Node do

  #generic test for all task of Thor class
  #test_task_interface(DTK::Client::Node)

  context "#list" do
  	command = "dtk node list"
  	output  = `#{command}`

  	it "should list all nodes" do
  		output.should match(/(node|id|empty|error|WARNING)/)
  	end
  end

end
