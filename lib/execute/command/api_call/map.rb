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
  class Command::APICall
    class Map < Hash
      def initialize(hash={})
        super()
        replace(hash)
      end

      def translate(api_params={},opts={})
        if Rest::Post.matches?(type())
          Command::RestCall::Post.new(:path => path(),:body => translate_to_rest_body(api_params,opts))
        else
          raise "Type in following map is not defined not defined: #{self.inspect}"
        end
      end

     private
      def translate_to_rest_body(api_params,opts)
        body().inject(Hash.new) do |h,(k,v)|
          # if TranslationTerm.matches is false then v is a constant
          processed_v = 
            if TranslationTerm.matches?(v)
              v.instance_form().translate(k,api_params,opts)
            else 
              v
            end
          h.merge(k => processed_v)
        end
      end

      def type()
        self[:type]
      end
      def path()
        self[:path]
      end
      def body()
        self[:body]
      end

    end
  end
end
