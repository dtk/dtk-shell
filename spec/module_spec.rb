require 'lib/spec_thor'

dtk_nested_require("../lib/commands/thor","module")

include SpecThor

describe DTK::Client::Module do
  $module_id = ''

  # list all modules and take one module_id
  context "#list" do
    output = `dtk module list`

    it "should have module listing" do
      output.should match(/(error|id|empty)/)
    end

    unless output.nil?
      $module_id = output.match(/\D([0-9]+)\D/)
    end
  end

  # for previously taken module_id, do show-components
  context "#list/command" do
    unless $module_id.nil?
      command = "dtk module #{$module_id} show-components"
      output  = `#{command}`

      it "should list all components for module with id #{$module_id}" do
        output.should match(/(error|id|name|empty)/)
      end
    end
  end

end
