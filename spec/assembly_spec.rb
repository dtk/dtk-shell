dtk_nested_require("../lib/commands/thor","assembly")
require 'lib/spec_thor'

include SpecThor

describe DTK::Client::Assembly do
  $about       = ['nodes', 'components', 'attributes','tasks']
  $assembly_id = nil

  #list all assemblies and take one assembly_id
  context '#list' do
    $assembly_list = run_from_dtk_shell('assembly list')

    it "should have assembly listing" do
      $assembly_list.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
    end

    unless $assembly_list.nil?
      unless $assembly_list['data'].nil?
        $assembly_id = $assembly_list['data'].first['id'] unless $assembly_list['data'].empty?
      end
    end
  end

  # for previously taken assembly_id, do list nodes|components|tasks
  context "#list/command" do
    unless $assembly_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("assembly #{$assembly_id} list #{type}")

        it "should list all #{type} for assembly with id #{$assembly_id}" do
          output.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
        end
      end
    end
  end

  # for previously taken assembly_id, do info
  context "#info" do
    unless $assembly_id.nil?
      output = run_from_dtk_shell("assembly #{$assembly_id} info")

      it "should show information about assembly with id #{$assembly_id}" do
        output.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
      end
    end
  end

end
