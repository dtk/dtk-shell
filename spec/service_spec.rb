require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/service', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::Service do
  $about       = ['assemblies']
  $service_id = nil


  #list all assemblies and take one assembly_id
  context '#list' do
    $service_list = run_from_dtk_shell('service list')
    
    it "should have service listing" do
      $service_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $service_list.nil?
      unless $service_list['data'].nil?
        $service_id = $service_list['data'].first['id'] unless $service_list['data'].empty?
      end
    end
  end


  context "#list/command" do
    unless $service_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("service #{$service_id} list #{type}")

        it "should list all #{type} for service with id #{$service_id}" do
          output.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
        end
      end
    end
  end

end

