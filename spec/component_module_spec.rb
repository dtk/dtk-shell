require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/component_module', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::ComponentModule do
  $component_module_id = nil

  context '#list' do
    $component_module_list = run_from_dtk_shell('component-module list')

    it "should have component module listing" do
      $component_module_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $component_module_list.nil?
      unless $component_module_list['data'].nil?
        $component_module_id = $component_module_list['data'].first['id'] unless $component_module_list['data'].empty?
      end
    end
  end

  context "#list/command" do
    unless $component_module_id.nil?
      output = run_from_dtk_shell("component-module #{$component_module_id} list-components")

      it "should list all components for component module with id #{$component_module_id}" do
        $component_module_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
      end
    end
  end

end
