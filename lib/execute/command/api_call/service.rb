#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
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