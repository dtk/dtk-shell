require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/library', File.dirname(__FILE__))

include SpecThor

describe DTK::Client::Library do
  $about      = ['nodes', 'components', 'assemblies']
  $library_id = nil

  #list all assemblies and take one assembly_id
  context '#list' do
    $library_list = run_from_dtk_shell('library list')

    it "should have library listing" do
      $library_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $library_list.nil?
      unless $library_list['data'].nil?
        $library_id = $library_list['data'].first['id'] unless $library_list['data'].empty?
      end
    end
  end

  context "#list/command" do
    unless $library_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("library #{$library_id} list #{type}")

        it "should list all #{type} for library with id #{$library_id}" do
          output.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
        end
      end
    end
  end
  
end
