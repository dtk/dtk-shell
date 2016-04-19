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
      r8_nested_require('fix', 'results')
      r8_nested_require('fix', 'set_attribute_mixin')
      class Result
        def skipped?
          kind_of?(Skipped)
        end
        def fixed?
          kind_of?(Fixed)
        end
        def error?
          kind_of?(Error)
        end

        class Skipped < self
        end
        class Fixed < self
        end
        class Error < self
        end
      end
      module SetAttributeMixin
        def initialize_set_attribute(attribute_hash)
          @attribute = Attribute.new(attribute_hash)
        end
      end
    end
  end
end

