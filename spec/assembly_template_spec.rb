require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","assembly_template")
include SpecThor


describe DTK::Client::AssemblyTemplate do
  #test_task_interface(DTK::Client::AssemblyTemplate)
  
  lists = ['none', 'nodes', 'components', 'targets']
  $assembly_template_id = ''

  context "#list" do
    output = `dtk assembly-template list`

    it "should contain assemblies" do
      output.should match(/(assembly|empty|Missing)/)
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
			         output.should match(/(assembly|empty)/)
			       end
  	  		when 'nodes'
			       command = "dtk assembly-template #{$assembly_template_id} list #{l}"
			       output = `#{command}`

			       it "should list all #{l} for assembly-template with id #{$assembly_template_id}" do
			         output.should match(/(name|empty)/)
			       end
			    when 'components'
				    command = "dtk assembly-template #{$assembly_template_id} list #{l}"
            output = `#{command}`

            it "should list all #{l} for assembly-template with id #{$assembly_template_id}" do
              output.should match(/(name|empty)/)
            end
			    when 'targets'
				    #TODO when check why we are getting internal error.
			    end
      end
	  end
  end

end