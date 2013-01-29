require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","node_template")
include SpecThor

describe DTK::Client::NodeTemplate do
  $node_template_id = nil

  #list all assemblies and take one assembly_id
  context '#list' do
    $node_template_list = run_from_dtk_shell('node-template list')

    it "should have node-template listing" do
      $node_template_list.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
    end

    unless $node_template_list.nil?
      $node_template_id = $node_template_list['data'].first['id'] unless ($node_template_list['data'].empty? || $node_template_list['data'].nil?)
    end
  end
	
end