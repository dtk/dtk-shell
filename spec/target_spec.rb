require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/target', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::Target do
  $about     = ['nodes', 'assemblies']
  $target_id = nil
  $provider_id = nil

  #list all providers and take one provider_id
  context '#list-providers' do
    $provider_list = run_from_dtk_shell('provider list')

    it "should have provider listing" do
      $provider_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $provider_list.nil?
      unless $provider_list['data'].nil?
        $provider_id = $provider_list['data'].first['id'] unless $provider_list['data'].empty?
      end
    end
  end

  #list all targets for particular provider and take one target_id
  context '#list-targets' do
    unless $provider_id.nil?
      $target_list = run_from_dtk_shell("provider #{$provider_id} list-targets")

      it "should have target listing" do
        $target_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
      end

      unless $target_list.nil?
        unless $target_list['data'].nil?
          $target_id = $target_list['data'].first['id'] unless $target_list['data'].empty?
        end
      end
    end
  end

  #list nodes and assemblies for particular target_id
  context "#list/command" do
    unless $target_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("provider #{$provider_id} target #{$target_id} list-#{type}")

        it "should list all #{type} for target with id #{$target_id}" do
          output.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
        end
      end
    end
  end

end