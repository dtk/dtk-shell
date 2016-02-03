class DTK::Client::Execute
 class Command::APICall::V1
    class Services < self
      def self.object_type()
        :services
      end

      CommandMap = {
        :create => Map.new(
          :type => Rest::Post,                             
          :path => "#{RoutePrefix}/services/create",
          :body => {
            :service_module_name   => Required(:service_module_name),
            :assembly_name         => Required(:assembly_name)
          }
        ),

        '_info'.to_sym  => Map.new(
          :type => Rest::Get,                             
          :path => "#{RoutePrefix}/services"
         )
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
