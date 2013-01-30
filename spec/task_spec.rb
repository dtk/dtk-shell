require 'lib/spec_thor'
dtk_nested_require("../lib/commands/thor","task")
include SpecThor

describe DTK::Client::Task do
  $task_id = nil

  #list all assemblies and take one assembly_id
  context '#list' do
    $task_list = run_from_dtk_shell('task list')

    it "should have assembly listing" do
      $task_list.to_s.should match(/(ok|status|empty|INFO|WARNING|name|id)/)
    end

    unless $task_list.nil?
      unless $task_list['data'].nil?
    	 $task_id = $task_list['data'].first['id'] unless $task_list['data'].empty?
      end
    end
  end

end