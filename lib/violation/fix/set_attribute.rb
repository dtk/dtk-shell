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
        def self.get_input_and_apply_fix(attribute)
          prompt_response = attribute.prompt_user_for_value
          if prompt_response.response_type == :skipped
            # TODO: may distinguish between skip current and skip all; no treating everything as skip all
            return Result.skip_all
          end
          
          prompted_value = prompt_response.value
          if attribute.illegal_value?(prompted_value)
            Result.error
          else
            begin
              attribute.set_and_propagate_value(prompted_value)
              Result.ok
            rescue => e
              DtkLogger.error_pp(e.message, e.backtrace)
              Result.error
            end
          end
        end
   
      end
    end
  end
end

