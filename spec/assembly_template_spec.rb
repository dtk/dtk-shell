require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/assembly', File.dirname(__FILE__))

include SpecThor


describe DTK::Client::AssemblyTemplate do
  $about                = ['nodes', 'components']
  $assembly_template_id = nil

  context '#list' do
    $assembly_template_list = run_from_dtk_shell('assembly-template list')

    it "should have assembly-template listing" do
      $assembly_template_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id|Missing)/)
    end

    unless $assembly_template_list.nil?
      unless $assembly_template_list['data'].nil?
        puts $assembly_template_list['data']
	$assembly_template_id = $assembly_template_list['data'].first['id'] unless $assembly_template_list['data'].empty?
      end
    end
  end

  context "#list/command" do
    unless $assembly_template_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("assembly-template #{$assembly_template_id} list #{type}")

        it "should list all #{type} for assembly-template with id #{$assembly_template_id}" do
          output.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
        end
      end
    end
  end

  context "#info" do
    unless $assembly_template_id.nil?
      output = run_from_dtk_shell("assembly-template #{$assembly_template_id} info")

      it "should show information about assembly-template with id #{$assembly_template_id}" do
        output.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
      end
    end
  end

end
