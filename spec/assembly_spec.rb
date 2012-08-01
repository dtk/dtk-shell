require File.expand_path('../lib/client', File.dirname(__FILE__))
require 'lib/spec_thor'

dtk_nested_require("../lib/parser/adapters","thor")
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
      output.should include("dtk assembly converge")
    end

    it "should have assembly export listing" do
      output.should include("dtk assembly export")
    end

  end

end
