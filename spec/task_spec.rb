require 'lib/spec_thor'
require File.expand_path('../lib/require_first', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/task', File.dirname(__FILE__))

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