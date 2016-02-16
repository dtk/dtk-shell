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
dtk_require('common_base')
module DTK; module Client; module Commands::Common
  class CreateTarget < Base
    # option_list is of form [:provider!, :region, :keypair, :security_group!] indcating what is optional and what is required
    def execute(type, option_list)
      # we use :target_id but that will return provider_id (another name for target template ID)
      target_name = retrieve_arguments([:option_1])
      iaas_properties = iaas_properties(type,option_list)
      provider = iaas_properties.delete(:provider)
      post_body = {
        :type             => type.to_s,
        :provider_id      => provider,
        :iaas_properties  => iaas_properties
      }

      # cleanup for target name not being sterilazied correctly
      post_body.merge!(:target_name => target_name.split(' ').first) if target_name

      post 'target/create', post_body
    end

   private
    def iaas_properties(type, option_list)
      iaas_properties = retrieve_option_hash(option_list)
      special_processing_security_groups!(iaas_properties)
      special_processing_region!(iaas_properties)
      iaas_properties
    end

    def special_processing_region!(iaas_properties)
      if region = iaas_properties[:region]
        Shell::InteractiveWizard.validate_region(region)
      end
      iaas_properties
    end

    def special_processing_security_groups!(iaas_properties)
      if security_group = iaas_properties[:security_group]
        if security_group.end_with?(',')
          raise DtkValidationError.new("Multiple security groups should be separated with ',' and without spaces between them (e.g. --security_groups gr1,gr2,gr3,...) ")
        end
        security_groups = security_group.split(',')

        unless security_groups.empty? || security_groups.size==1
          iaas_properties.delete(:security_group)
          iaas_properties.merge!(:security_group_set => security_groups)
        end
      end
      iaas_properties
    end

  end
end; end; end
