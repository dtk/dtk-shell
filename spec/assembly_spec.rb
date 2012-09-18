require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","assembly")
include SpecThor


describe DTK::Client::Assembly do

  
  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Assembly)


  # check help context menu
  context "Assembly CLI command (help)" do

    # notice backticks are being used here this runs commands
    output = `dtk assembly help`

    # Process::Status for above command
    process_status = $?

    it "should have assembly converge listing" do
      output.should include("converge")
    end

    it "should have assembly info listing" do
      output.should include("info")
    end

    it "should have assembly remove-component listing" do
      output.should include("remove-component")
    end

    it "should have assembly list listing" do
      output.should include("list")
    end

  end

end
