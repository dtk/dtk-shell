require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","library")
include SpecThor

describe DTK::Client::Library do
  $about      = ['nodes', 'components', 'assemblies']
  $library_id = nil

  #list all assemblies and take one assembly_id
  context '#list' do
    $library_list = run_from_dtk_shell('library list')

    it "should have library listing" do
      $library_list.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
    end

    $library_id = $library_list['data'].first['id'] unless ($library_list.nil? || $library_list['data'].empty?)
  end

  context "#list/command" do
    unless $library_id.nil?
      $about.each do |type|
        output = run_from_dtk_shell("library #{$library_id} list #{type}")

        it "should list all #{type} for library with id #{$library_id}" do
          output.to_s.should match(/(ok|status|empty|error|WARNING|name|id)/)
        end
      end
    end
  end
  
end
