require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/node_template', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::NodeTemplate do
  $node_template_id = nil

  context '#list' do
    $node_template_list = run_from_dtk_shell('node-template list')

    it "should have node-template listing" do
      $node_template_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $node_template_list.nil?
      unless $node_template_list['data'].nil?
        $node_template_id = $node_template_list['data'].first['id'] unless $node_template_list['data'].empty?
      end
    end
  end
	
end