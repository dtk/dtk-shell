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
			output.should match(/(node|id|empty|error)/)
		end

		unless output.nil?
			$node_id = output.match(/\D([0-9]+)\D/)
		end
	end

  	# for previously taken node id, do list none|tagets
	context "#list command" do
	  unless $node_id.nil?
		list.each do |list_element|
		  command = "dtk node-template #{$node_id} list #{list_element}"
		  output  = `#{command}`
          
		  it "should list all nodes" do
		   	output.should match(/(name|id|empty|error)/)
		  end
		end
	  end
	end

end