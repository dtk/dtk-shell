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
  module Violation::Fix
    class Result
      class Error < self
        def initialize(opts = {})
          super(:error)
          @error_msg = opts[:error_msg]
        end

        def render_error_msg
          OsUtil.print(@error_msg, :red) if @error_msg
        end
      end
    end
  end
end

