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
  class ExecuteContext
    class ResultStore < Hash
      def store(result,result_index=nil)
        self[result_index||Index.last] = result
      end

      def get_last_result?()
        self[Index.last]
      end
      
      module Index
        def self.last()
          Last
        end
        Last = :last
      end
    end
  end
end
