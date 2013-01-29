require 'lib/spec_thor'

dtk_nested_require("../lib/commands/thor","node_group")

include SpecThor

describe DTK::Client::NodeGroup do
	$about         = ['components', 'attributes']
  $node_group_id = nil

  #list all assemblies and take one assembly_id
  context '#list' do
    $node_group_list = run_from_dtk_shell('node-group list')

    it "should have node-group listing" do
      $node_group_list.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
    end

    unless $node_group_list.nil?
      $node_group_id = $node_group_list['data'].first['id'] unless ($node_group_list['data'].empty? || $node_group_list['data'].nil?)
    end
  end

  context "#list/command" do
    unless $node_group_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("node-group #{$node_group_id} list #{type}")

        it "should list all #{type} for node-group with id #{$node_group_id}" do
          output.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
        end
      end
    end
  end

end
