require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","component_template")
include SpecThor

describe DTK::Client::ComponentTemplate do
	#test_task_interface(DTK::Client::ComponentTemplate)

	lists = ['none', 'nodes']
	$component_template_id = ''

	context "#list" do
    	output = `dtk component-template list`

    	it "should contain component" do
      	output.should match(/(component|empty|Missing)/)
    	end

    	#TODO component-template list doesn't return values because
    	#we don't have table definition for data type COMPONENT
    	unless output.nil?
      		$component_template_id = output.match(/\D([0-9]+)\D/)
    	end
  	end

  	context "#list command" do
  	  unless $component_template_id.nil?
  	  	lists.each do |l|
  	  		case l
  	  		when 'none'
			    command = "dtk component-template #{$component_template_id} list none"
			    output = `#{command}`

			    it "should list all component_templates" do
			      output.should match(/(component|empty)/)
			    end
  	  		when 'nodes'
			    command = "dtk component-template #{$component_template_id} list #{l}"
			    output = `#{command}`

			    it "should list all #{l} for component-template with id #{$component_template_id}" do
			      output.should match(/(component|empty)/)
			    end
			end
      	end
	  end
    end

end