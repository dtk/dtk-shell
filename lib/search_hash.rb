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
    class SearchHash < Hash
      def cols=(cols)
        self.merge!(:columns => cols)
      end
      def filter=(filter)
        self.merge!(:filter => filter)
      end
      def set_order_by!(col,dir="ASC")
        unless %w{ASC DESC}.include?(dir)
          raise Error.new("set order by direction must by 'ASC' or 'DESC'")
        end
        order_by = 
          [{
          :field => col,
          :order => dir
        }]
        self.merge!(:order_by => order_by)
      end

      def post_body_hash()
        {:search => JSON.generate(self)}
      end
    end
  end
end