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
    module ActionResultHandler

      def print_action_results(action_results_id, number_of_retries=8)
        response = action_results(action_results_id, number_of_retries)

        if response.ok? && response.data['results']
          response.data['results'].each do |k,v|
            if v['error']
              OsUtil.print("#{v['error']} (#{k})", :red)
            else
              OsUtil.print("#{v['message']} (#{k})", :yellow)
            end
          end
        else
          OsUtil.print("Not able to process given request, we apologise for inconvenience", :red)
        end

        nil
      end

      def print_simple_results(action_results_id, number_of_retries=8)
        response = action_results(action_results_id, number_of_retries)
        pp response
      end

      def action_results(action_results_id, number_of_retries=8)
        action_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => true,
          :disable_post_processing => true
        }
        response = nil

        number_of_retries.times do
          response = post(rest_url("assembly/get_action_results"),action_body)

          # server has found an error
          unless response.data(:results).nil?
            if response.data(:results)['error']
              raise DTK::Client::DtkError, response.data(:results)['error']
            end
          end

          break if response.data(:is_complete)

          sleep(1.5)
        end

        response

      end

    end
  end
end
