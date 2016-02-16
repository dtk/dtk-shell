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
  class Dependency < CommandBaseThor
    desc "add-component COMPONENT-ID OTHER-COMPONENT-ID","Add before/require constraint"
    def add_component(context_params)
      component_id, other_component_id = context_params.retrieve_arguments([:option_1!,:option_2!],method_argument_names)
      post_body = {
        :component_id => component_id,
        :other_component_id => other_component_id,
        :type =>  "required by"
      }
      response = post rest_url("dependency/add_component_dependency"), post_body
      @@invalidate_map << :component_template

      return response
    end
  end
end
