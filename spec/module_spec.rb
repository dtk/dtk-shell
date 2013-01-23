require 'lib/spec_thor'

dtk_nested_require("../lib/commands/thor","module")

include SpecThor

describe DTK::Client::Module do
  $module_id = ''

  # list all modules and take one module_id
  context "#list" do
    output = `dtk module list`

    it "should have module listing" do
      output.should match(/(error|ID|NAME|empty|WARNING)/)
    end

    unless output.nil?
      $module_id = output.match(/\D([0-9]+)\D/)
    end
  end

  # for previously taken module_id, do list-components
  context "#list/command" do
    unless $module_id.nil?
      command = "dtk module #{$module_id} list-components"
      output  = `#{command}`

      it "should list all components for module with id #{$module_id}" do
        output.should match(/(error|ID|NAME|empty|WARNING)/)
      end
    end
  end

end
