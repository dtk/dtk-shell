require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::Dtk do

  # generic test for all task of Thor class
  #test_task_interface(DTK::Client::Dtk)

  context "Dtk CLI command" do

    f = IO.popen('dtk')
    output = f.readlines.join('')

    it "should have assembly listing" do
      output.should match(/(dtk|service|ok|status|empty|INFO|WARNING)/)
    end

    it "should have node listing" do
      output.should match(/(dtk|node|ok|status|empty|INFO|WARNING)/)
    end

    # it "should have repo listing" do
    #   output.should include("dtk repo")
    # end

    it "should have task listing" do
      output.should match(/(dtk|task|ok|status|empty|INFO|WARNING)/)
    end
  end
    
end
