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
  class Command
    class RestCall < self
      # TODO: allow calls like 'converge' which is a macro; we either directly support or have a sub class of RestCall called macro
      attr_reader :path
      def initialize(hash)
        super
        @path = required(:path)
      end

      class Post < self
        attr_reader :body
        def initialize(hash)
          super
          @body = optional?(:body)||{}
        end
      end
    end
  end
end