require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","node_template")
include SpecThor

describe DTK::Client::NodeTemplate do
	#test_task_interface(DTK::Client::NodeTemplate)

	list     = ['none', 'targets']
  	$node_id = ''

    # list all node-templates and take one node_id
	context "#list" do
		command = "dtk node-template list"
		output  = `#{command}`

		it "should list all nodes" do
			output.should match(/(NAME|ID|empty|error|WARNING)/)
		end

		unless output.nil?
			$node_id = output.match(/\D([0-9]+)\D/)
		end
	end
	
end