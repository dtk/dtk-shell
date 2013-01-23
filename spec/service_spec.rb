require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","service")
include SpecThor

describe DTK::Client::Service do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::ServiceModule)
  list        = ['none', 'assemblies']
  $service_id = ''

  # list all services and take one service_id
  context "#list" do
  	command = "dtk service list"
  	output  = `#{command}`

  	it "should list all modules" do
  		output.should match(/(ID|NAME|empty|error|WARNING)/)
  	end

  	unless output.nil?
  		$service_id = output.match(/\D([0-9]+)\D/)
  	end
  end

  # for previously taken service_id, do list none|assemblies
  context "#list command" do
  	unless $service_id.nil?
  		list.each do |list_element|

        command = "dtk service #{$service_id} list #{list_element}"
        output  = `#{command}`

        it "should list all modules or assemblies for service with id #{$service_id}" do
          output.should match(/(ID|NAME|empty|error|WARNING)/)
        end
  		end
  	end
  end

end

