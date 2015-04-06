class DTK::Client::Execute
  class Command::APICall
    class Service < self
      def self.object_type()
        :service
      end

      CommandMap = {
        :add_component => Map.new(
          :type => Rest::Post,                             
          :path => 'assembly/add_component',
          :body => {
            :assembly_id           => Required(:service),
            :subtype               => 'instance',
            :node_id               => Required(:node),
            :component_template_id => Required(:component),
            :namespace             => Required(:namespace),
            :idempotent            => Equal::OrDefault(true),
            :donot_update_workflow => Equal::OrDefault(false)
          }
        ),

        :set_attribute => Map.new(
          :type => Rest::Post,                             
          :path => 'assembly/set_attributes',
          :body => {
            :assembly_id => Required(:service),
            :pattern     => Required(:attribute_path),
            # TODO: support FN
            # :pattern   => FN{"#{Required(:node)}/#{Required(:component)}/#{Required(:attribute)}"
            :value       => Required::Equal
          }
        ),

        :link_components => Map.new(
          :type => Rest::Post,                             
          :path => 'assembly/add_service_link',
          :body => {
            :assembly_id         => Required(:service),
            :input_component_id  => Required(:input_component),
            :output_component_id => Required(:output_component),
          }
        ),

        :execute_workflow  => 
        [
         Map.new(
           :type => Rest::Post,                             
           :path => 'assembly/create_task',
           :body => {
             :assembly_id => Required(:service),
             :task_action => Required(:workflow_name),       
             :task_params => Required(:workflow_params)
            }
         ),
         Map.new(
           :type => Rest::Post,                             
           :path => 'task/execute',
           :body => {
             :task_id => PreviousResponse(:task_id)
           }
         )]
      }

      module CustomMapping
        # example would be
        # def self.command(params)
        #  ...
        # end
      end
      
    end
  end
end
