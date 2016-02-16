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

require 'thread'
require 'singleton'
require 'colorize'
#dtk_require('../commands')

# This singleton is used to check status on running processes on the server side
# Once certain task is complete it will give notice to user da certain task has been completed
# At the moment this only

module DTK
  module Shell
    class TaskStatusThread < Thread
      attr_accessor :task_id, :finished, :status

      def initialize
        @finished = false
        super
      end
    end

    class StatusMonitor
      include Singleton
      include DTK::Client::CommandBase

      THREAD_SLEEP_TIME = DTK::Configuration.get(:task_check_frequency)

      def initialize
        @threads        = []
        @finished_tasks = []
        @conn           = DTK::Client::Session.get_connection()
      end

      def self.start_monitoring(task_id)
        self.instance.start_monitoring(task_id)
      end

      def self.check_status
        self.instance.check_status
      end

      def check_status
        @threads.each do |t|
          if t.finished
            @finished_tasks << t
          end
        end

        # removes finished tasks from the main queue
        @threads = @threads - @finished_tasks

        @finished_tasks.each do |t|
          puts ""
          puts "[TASK NOTICE] Task with ID: #{t.task_id}, has finished with status: #{colorize_status(t.status)}"
        end

        @finished_tasks.clear
      end

      def start_monitoring(task_id)
        puts "Client has started monitoring task [ID:#{task_id}]. You will be notified when task has been completed."
        @threads << DTK::Shell::TaskStatusThread.new do
          begin
            response, post_hash_body = nil, {}
            post_hash_body[:task_id] = task_id
            DTK::Shell::TaskStatusThread.current.task_id = task_id

            # pooling server for task status
            while task_running?(response)
              sleep(THREAD_SLEEP_TIME) unless response.nil?
              response = post rest_url("task/status"),post_hash_body
              # we break if there is error in response
              break unless response.ok?
            end

            DTK::Shell::TaskStatusThread.current.finished = true

            if response.ok?
              DTK::Shell::TaskStatusThread.current.status = response.data['status'].upcase
            else
              DTK::Shell::TaskStatusThread.current.status = "RESPONSE NOT OK, RESPONSE: #{response}"
            end

          rescue Exception => e
            DtkLogger.instance.error_pp("[THREAD ERROR] Error getting task status with message: #{e.message}", e.backtrace)
          end
        end
      end

      private

      def colorize_status(status)
        color = status.eql?('FAILED') ? :red : :green
        return DTK::Client::OsUtil.colorize(status, color)
      end

      # return true   if status SUCCEDED, FAILED
      # returns false if status EXECUTING
      def task_running?(response)
        return true if response.nil?
        return !(response.data['status'].eql?("succeeded") || response.data['status'].eql?("failed"))
      end

    end
  end
end