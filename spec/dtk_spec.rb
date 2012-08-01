require File.expand_path('../lib/client', File.dirname(__FILE__))

require 'rspec'
require 'stringio'

# TODO Find smarter way to load dependencies and then use class variable
describe 'DTK::Client::Dtk' do
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
