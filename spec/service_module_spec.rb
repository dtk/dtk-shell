require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","service_module")
include SpecThor

describe DTK::Client::ServiceModule do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::ServiceModule)
  lists = ['none', 'assemblies']
  $module_id = ''

  context "#list" do
  	command = "dtk service-module list"
  	output = `#{command}`

  	it "should list all modules" do
  		output.should match(/(module|empty|error)/)
  	end

  	unless output.nil?
  		$module_id = output.match(/\D([0-9]+)\D/)
  	end
  end

  context "#list command" do
  	unless $module_id.nil?
  		lists.each do |l|
  			case l
  			when 'none'
  				command = "dtk service-module #{$module_id} list #{l}"
  				output  = `#{command}`

  				it "should list all modules" do
  					output.should match(/(module|empty|error)/)
  				end
  			when 'assemblies'
  				command = "dtk service-module #{$module_id} list #{l}"
  				output  = `#{command}`

  				it "should list all assemblies for module with id #{$module_id}" do
  					output.should match(/(assembly|empty|error)/)
  				end
  			end
  		end
  	end
  end

end

