require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","target")
include SpecThor

describe DTK::Client::Target do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Target)

  lists = ['none', 'nodes', 'assemblies']
  $target_id = ''

  context "#list" do
    output = `dtk target list`

    it "should list all targets" do
      output.should include("target")
    end

    unless output.nil?
      $target_id = output.match(/\D([0-9]+)\D/)
    end
  end

  context "#list command" do
  	unless $target_id.nil?
  		lists.each do |l|
  			case l
  			when 'none'
  				command = "dtk target #{$target_id} list #{l}"
			    output = `#{command}`

			    it "should list all targets" do
			       output.should include("target")
			    end
			when 'nodes'
				command = "dtk target #{$target_id} list #{l}"
			    output = `#{command}`

			    it "should list all #{l} for target with id #{$target_id}" do
			       output.should include("node")
			    end
			when 'assemblies'
				command = "dtk target #{$target_id} list #{l}"
			    output = `#{command}`

			    it "should list all #{l} for target with id #{$target_id}" do
			       output.should include("assembly")
			    end
			end
  		end
  	end
  end

end

