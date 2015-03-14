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
            :assembly_id           => Equal::Required,
            :subtype               => 'instance',
            :node_id               => Equal::Required,
            :component_template_id => Equal::Required

          }
        )
      }

    end
  end
end
