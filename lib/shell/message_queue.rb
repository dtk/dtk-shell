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
# TODO-REMOVE: Check if we need this anymore

dtk_require_from_base('util/os_util')

module DTK
  module Shell
    class MessageQueue
      include Singleton

      MESSAGE_TYPES = [:info, :warn, :error]

      def initialize
        @queue = {}
        init_or_clear()
      end

      def self.process_response(response_obj)
        self.instance.process_response(response_obj)
      end

      def self.print_messages()
        self.instance.print_messages()
      end

      def init_or_clear()
        MESSAGE_TYPES.each { |msg_type| @queue[msg_type] = [] }
      end

      def print_messages()
        @queue[:info].each  { |msg| DTK::Client::OsUtil.print(msg, :white) }
        @queue[:warn].each  { |msg| DTK::Client::OsUtil.print(msg, :yellow) }
        @queue[:error].each { |msg| DTK::Client::OsUtil.print(msg, :red) }

        init_or_clear()
      end

      def process_response(response_obj)
        MESSAGE_TYPES.each do |msg_type|
          msg = response_obj[msg_type.to_s] || response_obj[msg_type]
          @queue[msg_type] << msg if msg
        end
      end

    end
  end
end