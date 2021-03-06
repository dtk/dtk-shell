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
  class Violation
    module Fix
      module SetAttribute
        def self.get_input_and_apply_fix(service_id, attribute)
          prompt_response = attribute.prompt_user_for_value
          if prompt_response.response_type == :skipped
            # TODO: may distinguish between skip current and skip all; now treating everything as skip all
            return Result.skip_all
          end
          
          prompted_value = prompt_response.value
          if error_msg = attribute.illegal_value?(prompted_value)
            Result.error :error_msg => error_msg
          else
            attribute.set_attribute(service_id, prompted_value)
          end
        end
   
      end
    end
  end
end

