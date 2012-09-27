require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","library")
include SpecThor

describe DTK::Client::Library do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Library)

  lists = ['nodes', 'components', 'assemblies']
  $library_id = ''

  context "Dtk CLI list command" do
    output = `dtk library list`

    it "should list libraries" do
      output.should match(/(library|id|empty)/)
    end

    unless output.nil?
      $library_id = output.match(/\D([0-9]+)\D/)
    end
  end

  context "Dtk CLI list specific library" do
  	 unless $library_id.nil?
  	  	 lists.each do |l|

  	  		 case l
  	  		 when 'nodes'
			     command = "dtk library #{$library_id} list #{l}"
			     output = `#{command}`

			     it "should list all #{l} for library with id #{$library_id}" do
			       output.should match(/(node|id|empty|error)/)
			     end
			     when 'components'
            command = "dtk library #{$library_id} list #{l}"
            output = `#{command}`

            it "should list all #{l} for library with id #{$library_id}" do
             output.should match(/(component|id|empty|error)/)
            end
			     when 'assemblies'
            command = "dtk library #{$library_id} list #{l}"
            output = `#{command}`

            it "should list all #{l} for library with id #{$library_id}" do
             output.should match(/(assembly|id|empty|error)/)
            end
			     end
      	 end
	   end
  end

end
