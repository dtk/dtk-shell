require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","component_template")
include SpecThor

describe DTK::Client::ComponentTemplate do
  $about                 = ['none', 'nodes']
  $component_template_id = nil

  context '#list' do
    $component_template_list = run_from_dtk_shell('component-template list')

    it "should have assembly listing" do
      $component_template_list.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
    end

    unless $component_template_list.nil?
      $component_template_id = $component_template_list['data'].first['id'] unless $component_template_list['data'].nil?
    end
  end

  context "#list/command" do
    unless $component_template_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("component-template #{$component_template_id} list #{type}")

        it "should list all #{type} for component-template with id #{$component_template_id}" do
          output.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
        end
      end
    end
  end

end