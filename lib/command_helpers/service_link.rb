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
module DTK; module Client; class CommandHelper
  class ServiceLink < self; class << self
    def post_body_with_id_keys(context_params,method_argument_names)
      assembly_or_workspace_id = context_params.retrieve_arguments([[:service_id!,:workspace_id!]])
      ret = {:assembly_id => assembly_or_workspace_id}
      if context_params.is_last_command_eql_to?(:component)
        component_id,service_type = context_params.retrieve_arguments([:component_id!,:option_1!],method_argument_names)
        ret.merge(:input_component_id => component_id,:service_type => service_type)
      else
        service_link_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
        ret.merge(:service_link_id => service_link_id)
      end
    end

  end; end
end; end; end