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
require 'hirb'
module DTK::Client
  class TaskStatus
    class StreamMode < self
      require File.expand_path('stream_mode/element', File.dirname(__FILE__))

      def get_and_render(opts = {})
        Element.get_and_render_task_start(self, opts)
        Element.get_and_render_stages(self, {:wait => WaitWhenNoResults}.merge(opts))
        Response::Ok.new()
      end

      WaitWhenNoResults = 5 #in seconds
      # making this public for this class and its children
      def post_call(*args)
        super
      end

      private
      
      # This uses a cursor based interface to the server
      #    start_index: START_INDEX
      #    end_index: END_INDEX
      # convention is start_position = 0 and end_position = 0 means top level task with start time 
      def post_body(opts = {})
        ret = super(opts)
        ret.merge(:start_index => opts[:start_index], :end_index => opts[:end_index])
      end
    end
  end
end