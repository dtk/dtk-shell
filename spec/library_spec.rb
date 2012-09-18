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

    it "should be string" do
      output.should be_a_kind_of(String)
    end

    unless output.nil?
      $library_id = output.match(/\D([0-9]+)\D/)
    end
  end

 #  context "Dtk CLI list specific library" do
 #  	unless $library_id.nil?
 #  	  	lists.each do |l|
	# 	    command = "dtk library #{$library_id} list #{l}"
	# 	    output = `#{command}`

	# 	    it "should list all #{l} for library with id #{$library_id}" do
	# 	      output.should include("#{l.singularize}")
	# 	    end
 #      	end
	# end
 #  end

 #TODO change this with code commented above
 #when make sure that all commands are implemented properly
  context "Dtk CLI list specific library" do
  	 unless $library_id.nil?
  	  	 lists.each do |l|

  	  		 case l
  	  		 when 'nodes'
			     command = "dtk library #{$library_id} list #{l}"
			     output = `#{command}`

			     it "should list all #{l} for library with id #{$library_id}" do
			       output.should include("#{l.singularize}")
			     end
			     when 'components'
			     when 'assemblies'
			     end
      	 end
	   end
  end

end
