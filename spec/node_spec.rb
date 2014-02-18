require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/node', File.dirname(__FILE__))

include SpecThor

#Currently disabled because this context does not exist anymore
=begin
describe DTK::Client::Node do
	$about   = ['components', 'attributes']
  $node_id = nil

  #list all assemblies and take one assembly_id
  context '#list' do
    $node_list = run_from_dtk_shell('node list')

    it "should list all nodes" do
      $node_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $node_list.nil?
      unless $node_list['data'].nil?
        $node_id = $node_list['data'].first['id'] unless $node_list['data'].empty?
      end
    end
  end

  #current dtk-client code for this test is not implemented
  
  # context "#list/command" do
  #   unless $node_id.nil?
  #     $about.each do |type|
  #       output = run_from_dtk_shell("node #{$node_id} list #{type}")

  #       it "should list all #{type} for node with id #{$node_id}" do
  #         output.to_s.should match(/(ok|status|id|name|empty|error|WARNING)/)
  #       end
  #     end
  #   end
  # end

end
=end
