require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","assembly_template")
include SpecThor


describe DTK::Client::AssemblyTemplate do
  #test_task_interface(DTK::Client::AssemblyTemplate)
  
  # add 'targets' when we implement them in AssemblyTemplate
  list                  = ['nodes', 'components']
  $assembly_template_id = ''

  # list all assembly-templates and take one assembly_template_id
  context "#list" do
    output = `dtk assembly-template list`

    it "should contain assemblies" do
      output.should match(/(assembly|id|empty|Missing|error|WARNING)/)
    end

    unless output.nil?
      $assembly_template_id = output.match(/\D([0-9]+)\D/)
    end
  end

  # for previously taken assembly_template_id, do list nodes|components|targets
  context "#list command" do
  	unless $assembly_template_id.nil?
      list.each do |list_element|
        command = "dtk assembly-template #{$assembly_template_id} list #{list_element}"
        output  = `#{command}`

        it "should list all #{list_element} for assembly-template with id #{$assembly_template_id}" do
          output.should match(/(name|id|empty|error|WARNING)/)
        end
      end
	  end
  end

end