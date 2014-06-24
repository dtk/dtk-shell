require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/assembly', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::Assembly do
  $about       = ['nodes', 'components', 'attributes','tasks']
  $service_id = nil

  #list all services and take one service_id
  context "#list" do
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

  # for previously taken service_id, do list nodes|components|tasks
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

  # for previously taken service_id, do info
  context "#info" do
    unless $service_id.nil?
      output = run_from_dtk_shell("service #{$service_id} info")

      it "should show information about service with id #{$service_id}" do
        output.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
      end
    end
  end

end
