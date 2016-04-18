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
  class TaskStatus
    class RefreshMode < self
      DEBUG_SLEEP_TIME = DTK::Configuration.get(:debug_task_frequency)

      def task_status(opts={})
        begin
          response = nil
          loop do
            response = post_call(opts)
            return response unless response.ok?
            
            # stop pulling when top level task succeds, fails or timeout
            if response and response.data and response.data.first
              #TODO: may fix in server, but now top can have non executing state but a concurrent branch can execute; so
              #chanding bloew for time being
              #break unless response.data.first["status"].eql? "executing"
              # TODO: There is bug where we do not see executing status on start so we have to wait until at
              # least one 'successed' has been found
              
              top_task_failed = response.data.first['status'].eql?('failed')
              is_pending   = (response.data.select {|r|r["status"].nil? }).size > 0
              is_executing = (response.data.select {|r|r["status"].eql? "executing"}).size > 0
              is_failed    = (response.data.select {|r|r["status"].eql? "failed"}).size > 0
              is_cancelled = response.data.first["status"].eql?("cancelled")
              
              # commented out because of DTK-1804
              # when some of the converge tasks fail, stop task-status --wait and set task status to '' for remaining tasks which are not executed
              # if is_failed
                # response.data.each {|r| (r["status"] = "") if r["status"].eql?("executing")}
              # is_cancelled = true
              # end
              is_cancelled = true if top_task_failed
              
              unless (is_executing || is_pending) && !is_cancelled
                system('clear')
                response.print_error_table = true
                response.render_table(:task_status)
                return response
              end
            end
            
            response.render_table(:task_status)
            system('clear')
            response.render_data(true)
            
            Console.wait_animation("Watching '#{@object_type}' task status [ #{DEBUG_SLEEP_TIME} seconds refresh ] ", DEBUG_SLEEP_TIME)
          end
          rescue Interrupt => e
          puts ""
          # this tells rest of the flow to skip rendering of this response
          response.skip_render = true unless response.nil?
        end

      end
    end
  end
end

