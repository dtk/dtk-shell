require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::Target do
  $about     = ['nodes', 'assemblies']
  $target_id = nil

  #list all assemblies and take one assembly_id
  context '#list' do
    $target_list = run_from_dtk_shell('target list')

    it "should have target listing" do
      $target_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $target_list.nil?
      unless $target_list['data'].nil?
        $target_id = $target_list['data'].first['id'] unless $target_list['data'].empty?
      end
    end
  end


  context "#list/command" do
    unless $target_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("target #{$target_id} list #{type}")

        it "should list all #{type} for target with id #{$target_id}" do
          output.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
        end
      end
    end
  end

end

