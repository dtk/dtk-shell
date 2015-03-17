class DTK::Client::Execute
  class Command::APICall
    class Service < self
      def self.object_type()
        :service
      end

      def self.Required(key)
         Required.new(key)
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


      }

    end
  end
end
