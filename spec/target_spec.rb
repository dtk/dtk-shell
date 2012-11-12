require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","target")
include SpecThor

describe DTK::Client::Target do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Target)

  list       = ['nodes', 'assemblies']
  $target_id = ''

  # list all targets and take one target_id
  context "#list" do
    output = `dtk target list`

    it "should list all targets" do
      output.should match(/(target|id|empty|error|WARNING)/)
    end

    unless output.nil?
      $target_id = output.match(/\D([0-9]+)\D/)
    end
  end

  # for previously taken target_id, do list nodes|assemblies
  context "#list command" do
  	unless $target_id.nil?
  		list.each do |list_element|
        command = "dtk target #{$target_id} show #{list_element}"
        output  = `#{command}`

        it "should list all nodes | assemblies" do
          output.should match(/(name|id|empty|error|WARNING)/)
        end
  		end
  	end
  end

end

