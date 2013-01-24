require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","service")
include SpecThor

describe DTK::Client::Service do
  $about       = ['assemblies']
  $service_id = nil


  #list all assemblies and take one assembly_id
  context '#list' do
    $service_list = run_from_dtk_shell('service list')
    
    it "should have service listing" do
      $service_list.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
    end

    $service_id = $service_list['data'].first['id'] unless ($service_list.nil? || $service_list['data'].empty?)
  end


  context "#list/command" do
    unless $service_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("service #{$service_id} list #{type}")

        it "should list all #{type} for service with id #{$service_id}" do
          output.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
        end
      end
    end
  end

end

