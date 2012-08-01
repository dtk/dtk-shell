require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","dtk")
include SpecThor

describe DTK::Client::Dtk do

  # generic test for all task of Thor class
  test_task_interface(DTK::Client::Dtk)

  context "Dtk CLI command" do

    f = IO.popen('dtk')
    output = f.readlines.join('')

    it "should have assembly listing" do
      output.should include("dtk assembly")
    end

    it "should have node listing" do
      output.should include("dtk node")
    end

    it "should have repo listing" do
      output.should include("dtk repo")
    end

    it "should have task listing" do
      output.should include("dtk task")
    end

  end
end
