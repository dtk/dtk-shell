require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","library")
include SpecThor

describe DTK::Client::Library do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Library)

  list        = ['nodes', 'components', 'assemblies']
  $library_id = ''

  # list all libraries and take one library_id
  context "Dtk CLI list command" do
    output = `dtk library list`

    it "should list libraries" do
      output.should match(/(library|id|empty|error)/)
    end

    unless output.nil?
      $library_id = output.match(/\D([0-9]+)\D/)
    end
  end

  # for previously taken library_id, do list nodes|compoenents|assemblies
  context "Dtk CLI list specific library" do
  	unless $library_id.nil?
  	  list.each do |list_element|
        command = "dtk library #{$library_id} list #{list_element}"
        output = `#{command}`

        it "should list all #{list_element} for library with id #{$library_id}" do
          output.should match(/(name|id|empty|error)/)
        end
      end
	  end
  end

end
