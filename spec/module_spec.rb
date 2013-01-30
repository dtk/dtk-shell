dtk_nested_require("../lib/commands/thor","module")
require 'lib/spec_thor'

include SpecThor

describe DTK::Client::Module do
  $module_id = nil

  #list all assemblies and take one assembly_id
  context '#list' do
    $module_list = run_from_dtk_shell('module list')

    it "should have module listing" do
      $module_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $module_list.nil?
      unless $module_list['data'].nil?
        $module_id = $module_list['data'].first['id'] unless $module_list['data'].empty?
      end
    end
  end

  context "#list/command" do
    unless $module_id.nil?
      output = run_from_dtk_shell("module #{$module_id} list-components")

      it "should list all components for module with id #{$module_id}" do
        $module_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
      end
    end
  end

end
