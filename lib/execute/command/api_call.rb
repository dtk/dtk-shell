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
    class APICall < self

      # order matters; having these defs before requires; plus order of these requires
      def self.Required(key)
        Required.new(key)
      end
      def self.PreviousResponse(response_key)
        PreviousResponse.new(response_key)
      end
      dtk_require('api_call/translation_term')
      dtk_require('api_call/map')
      dtk_require('api_call/service')


       # calss block where on one or more commands that achieve the api
      def raw_executable_commands(&block)
        method = required(:method).to_sym
        case required(:object_type).to_sym
         when :service
           Service.raw_executable_commands(method,&block)
         else
          raise ErrorUsage.new("The object_type '#{object_type}' is not supported")
        end
      end

     private
      def self.raw_executable_commands(method,&block)
        if command_map = self::CommandMap[method]
          array_form(command_map).each{|raw_command|block.call(raw_command)}
        else
          raise ErrorUsage.new("The method on '#{method}' on object type '#{object_type()}' is not supported")
        end
      end

      def self.array_form(obj)
        obj.kind_of?(Array) ? obj : [obj]
      end

    end
  end
end