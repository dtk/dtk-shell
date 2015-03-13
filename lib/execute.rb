module DTK::Client
  class Execute
    # The order matters
    dtk_require('execute/error_usage')
    dtk_require('execute/command')
    dtk_require('execute/iterate')

    def self.test()
      commands = Array.new
#      commands << Command::RestCall::Post.new(:path => 'service_module/list')
      commands << Command::RestCall::Post.new(:path => 'assembly/info_about_task',:body => {:assembly_id => 'dtkhost5', :subtype => 'instance'})
      # TODO: assembly/add_component does not take form where node_id is string
      server = 2147498350
      commands << Command::RestCall::Post.new(:path => 'assembly/add_component',:body => {:assembly_id => 'dtkhost5',:subtype => 'instance', :node_id => server,:component_template_id => 'dtk_tenant[dtk524]'})
      Iterate.iterate_over_script(commands)

    end
  end
end


=begin
Comamnds we want to do to add tenant
# add component; we want to modify so there is a flag that allows this to be idemponent and another one to be 
{:operation=>"assembly/add_component",
 :params=>
  {"assembly_id"=>"2147498349",
   :subtype => 'instance' 
   "node_id"=>"2147498350",
   "component_template_id"=>"dtk_tenant[dtk523]"}}

# link component


=end
