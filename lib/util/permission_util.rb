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
module DTK
  module Client
    module PermissionUtil
      class << self
        def validate_permissions!(permission_string)
          # matches example: u-rw, ugo+r, go+w
          match = permission_string.match(/^[ugo]+[+\-][rwd]+$/)
          raise DTK::Client::DtkValidationError, "Provided permission expression ('#{permission_string}') is not valid" unless match
          permission_string
        end
      end
    end
  end
end
