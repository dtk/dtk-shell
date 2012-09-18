require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","node_template")
include SpecThor

describe DTK::Client::NodeTemplate do
	#test_task_interface(DTK::Client::NodeTemplate)

	lists = ['none', 'targets']
  	$node_id = ''

	context "#list" do
		command = "dtk node-template list"
		output = `#{command}`

		it "should list all nodes" do
			output.should include("node")
		end

		unless output.nil?
			$node_id = output.match(/\D([0-9]+)\D/)
		end
	end

	context "#list command" do
		unless $node_id.nil?
			lists.each do |l|
				case l
  	  		 	when 'none'
			     	command = "dtk node-template #{$node_id} list #{l}"
					output = `#{command}`

			     	it "should list all nodes" do
			       		output.should include("node")
			     	end
			    when 'targets'
			    	command = "dtk node-template #{$node_id} list #{l}"
					output = `#{command}`

			     	it "should list all nodes" do
			       		output.should include("node")
			     	end
			    end
			end
		end
	end
end