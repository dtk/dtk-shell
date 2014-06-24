require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/service_module', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::ServiceModule do
  $about       = ['assemblies']
  $service_module_id = nil

  context '#list' do
    $service_module_list = run_from_dtk_shell('service-module list')

    it "should have service modules listing" do
      $service_module_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $service_module_list.nil?
      unless $service_module_list['data'].nil?
        $service_module_id = $service_module_list['data'].first['id'] unless $service_module_list['data'].empty?
      end
    end
  end

  context "#list/command" do
    unless $service_module_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("service-module #{$service_module_id} list #{type}")

        it "should list all #{type} for service module with id #{$service_module_id}" do
          output.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
        end
      end
    end
  end

end

