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
module DTK::Client; class TaskStatus::StreamMode
  class Element
    class Stage < self
      require File.expand_path('stage/render', File.dirname(__FILE__))
      include Render::Mixin

      def initialize(response_element, opts = {})
        super
        @just_render = opts[:just_render]
      end
      
      # opts has
      #   :wait - amount to wait if get no results (required)
      def self.get_and_render_stages(task_status_handle, opts = {})
        unless wait = opts[:wait]
          raise DtkError::Client, "opts[:wait] must be set"
        end
        
        cursor = Cursor.new
        until cursor.task_end? do
          elements = get_single_stage(task_status_handle, cursor.stage, {:wait_for => cursor.wait_for}.merge(opts))
          if no_results_yet?(elements)
            sleep wait
            next
          end
          render_elements(elements)
          cursor.advance!(task_end?(elements))
        end
      end
    
      class Cursor
        def initialize
          @stage    = 1
          @wait_for = :start
          @task_end = false
        end
        attr_reader :stage, :wait_for
        def task_end?
          @task_end
        end
        def advance!(task_end)
          unless @task_end = task_end
            if @wait_for == :start
              @wait_for = :end
            else
              @stage += 1
              @wait_for = :start
            end
          end
        end
      end
      
      def self.get_single_stage(task_status_handle, stage_num, opts = {})
        get_stages(task_status_handle, stage_num, stage_num, opts)
      end
      
      def self.get_stages(task_status_handle, start_stage_num, end_stage_num, opts = {})
        opts_get = {
          :start_index => start_stage_num, 
          :end_index   => end_stage_num
        }.merge(opts)
        get_task_status_elements(task_status_handle, :stage, opts_get)
      end
      
    end
  end
end; end
