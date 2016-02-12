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

module DTK::Client
  class Attribute < CommandBaseThor

    no_tasks do

      def self.assembly_validation_list(context_params)
        assembly_or_worspace_id, node_id, component_id = context_params.retrieve_arguments([[:service_id!, :workspace_id!], :node_id!, :component_id!])

        post_body = {
          :assembly_id  => assembly_or_worspace_id,
          :node_id      => node_id,
          :component_id => component_id,
          :subtype      => 'instance',
          :about        => 'attributes',
          :filter       => nil
        }

        response = get_cached_response(:service_node_component_attribute, "assembly/info_about", post_body)
        modified_response = response.clone_me()

        modified_response['data'].each { |e| e['display_name'] = e['display_name'].split('/').last }
          
        return modified_response
      end

      def self.module_validation_list(context_params)
        component_module_id = context_params.retrieve_arguments([:module_id!])

        post_body = {
          :component_module_id => component_module_id,
          :about => :attributes
        }
        response = post rest_url("component_module/info_about"), post_body
           
        modified_response = response.clone_me()
        modified_response['data'].each { |e| e['display_name'] = e['display_name'].split('/').last }
        #modified_response['data'].each { |e| e['display_name'] = e['display_name'].match(/.+\[.+::(.*)\]/)[1] }
        
        return modified_response
      end

    end

    def self.validation_list(context_params)
      command_name = context_params.root_command_name

      case command_name
      when 'service'
        return assembly_validation_list(context_params)
      when 'workspace'
        return assembly_validation_list(context_params)
      when 'module'
        return module_validation_list(context_params)
      else
        raise DTK::Client::DtkError,"Attribute 'validation_list' not supported for #{command_name}, implementation nedeed."
      end
    end


  end
end