require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","node")
include SpecThor

describe DTK::Client::Node do

  #generic test for all task of Thor class
  #test_task_interface(DTK::Client::Node)

  context "#list" do
  	command = "dtk node list"
  	output = `#{command}`

  	it "should list all nodes" do
  		output.should include("node_id")
  	end
  end

  #TODO uncomment this when we have nodes in targets
  # context "#list -t" do
  # 	command = "dtk node list -t"
  # 	output = `#{command}`

  # 	it "should list nodes only in targets" do
  # 		output.should include("node_id")
  # 	end
  # end

  context "#list -l" do
  	command = "dtk node list -l"
  	output = `#{command}`

  	it "should list nodes only in libraries" do
  		output.should include("node_id")
  	end
  end

end
