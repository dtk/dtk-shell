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
  module Poller

    PERIOD_WAIT_TIME = 1

    def poller_response(wait_time = PERIOD_WAIT_TIME)
      begin
        response = nil
        thread   = Thread.new(self) do |main_thread|
          begin
            while true
              messages_response = main_thread.get main_thread.rest_url("messages/retrieve")
              print_response(messages_response.data) if messages_response.ok?
              sleep(wait_time)
            end
          rescue => e
            puts e.message
            pp e.backtrace
          end
        end

        response = yield
      ensure
        thread.kill
      end
      response
    end

    def print_response(message_array)
      message_array.each do |msg|
        DTK::Client::OsUtil.print(msg['message'], resolve_type(msg['type']))
      end
    end

    def resolve_type(message_type)
      case message_type.to_sym
      when :info
        :white
      when :warning
        :yellow
      when :error
        :red
      else
        :white
      end
    end
  end
end
