require 'lib/spec_thor'
include SpecThor

describe "dtk-shell" do

context '#1'do
	system("echo 'assembly list' | dtk-shell")	
	#system("echo 'cc assembly'")
end

context '#2' do
	exec('exit')
	#system("exit")
end
end

