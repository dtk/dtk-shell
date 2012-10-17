require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","assembly")
include SpecThor


describe DTK::Client::Assembly do
  list = ['nodes', 'components', 'tasks']
  $assembly_id = ''
  
  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Assembly)

  # list all assemblies and take one assembly_id
  context "#list" do
    output = `dtk assembly list`

    it "should have assembly listing" do
      output.should match(/(assembly|id|empty|error)/)
    end

    unless output.nil?
      $assembly_id = output.match(/\D([0-9]+)\D/)
    end
  end

  # for previously taken assembly_id, do show nodes|components|tasks
  context "#list/command" do
    unless $assembly_id.nil?
      list.each do |list_element|
        command = "dtk assembly #{$assembly_id} show #{list_element}"
        output = `#{command}`

        it "should list all #{list_element} for assembly with id #{$assembly_id}" do
          output.should match(/(id|name|empty|error)/)
        end
      end
    end
  end

  # check help context menu
  context "#help" do
    # notice backticks are being used here this runs commands
    output = `dtk assembly help`

    # Process::Status for above command
    process_status = $?

    it "should have assembly converge listing" do
      output.should match(/(converge|empty|error)/)
    end

    it "should have assembly info listing" do
      output.should match(/(info|empty|error)/)
    end

    it "should have assembly remove-component listing" do
      output.should match(/(remove-component|empty|error)/)
    end

    it "should have assembly list listing" do
      output.should match(/(list|empty|error)/)
    end

  end

end
