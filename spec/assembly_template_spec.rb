require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","assembly_template")
include SpecThor


describe DTK::Client::AssemblyTemplate do
  #test_task_interface(DTK::Client::AssemblyTemplate)
  
  lists = ['none', 'nodes', 'components', 'targets']
  $assembly_template_id = ''

  context "#list" do
    output = `dtk assembly-template list`

    it "should be string" do
      output.should be_a_kind_of(String)
    end

    unless output.nil?
      $assembly_template_id = output.match(/\D([0-9]+)\D/)
    end
  end

  context "#list command" do
  	unless $assembly_template_id.nil?
  	  lists.each do |l|
  	  		case l
  	  		when 'none'
			       command = "dtk assembly-template #{$assembly_template_id} list none"
			       output = `#{command}`

			       it "should list all assembly_templates" do
			         output.should include("assembly")
			       end
  	  		when 'nodes'
			       command = "dtk assembly-template #{$assembly_template_id} list #{l}"
			       output = `#{command}`

			       it "should list all #{l} for assembly-template with id #{$assembly_template_id}" do
			         output.should include("name")
			       end
			    when 'components'
				    #TODO when check why we don't have table definition for data type COMPONENT
			    when 'targets'
				    #TODO when check why we are getting internal error.
			    end
      end
	  end
  end

end