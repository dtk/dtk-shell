require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/component_template', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::ComponentTemplate do
  $about                 = ['none', 'nodes']
  $component_template_id = nil

  context '#list' do
    $component_template_list = run_from_dtk_shell('component-template list')

    it "should have assembly listing" do
      $component_template_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $component_template_list.nil?
      unless $component_template_list['data'].nil?
        $component_template_id = $component_template_list['data'].first['id'] unless $component_template_list['data'].empty?
      end
    end
  end

  context "#list/command" do
    unless $component_template_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("component-template #{$component_template_id} list #{type}")

        it "should list all #{type} for component-template with id #{$component_template_id}" do
          output.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
        end
      end
    end
  end

end