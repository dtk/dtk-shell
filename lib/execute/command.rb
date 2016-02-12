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
    dtk_require('command/rest_call')
    dtk_require('command/api_call')

    attr_reader :result_var,:input_hash
    def initialize(input_hash)
      @input_hash = input_hash
      @result_var = optional?(:result_var)
    end

   private
    def required(key)
      unless @input_hash.has_key?(key)
        raise ErrorUsage.new("Missing required key '#{key}' in: #{@input_hash.inspect}")
      end
      @input_hash[key]
    end
    def optional?(key)
      @input_hash[key]
    end
  end
end