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
    module CommandBase
      #TODO: temp workaround
      def rotate_args(rotated_args)
        [rotated_args.last] + rotated_args[0..rotated_args.size-2]
      end

      def get(url)
        get_connection.get(self.class,url)
      end
      def post(url,body=nil)
        get_connection.post(self.class,url,body)
      end

      def post_file(url,body=nil)
        get_connection.post_file(self.class,url,body)
      end

      def rest_url(route)
        get_connection.rest_url(route)
      end

      def get_connection
        DTK::Client::Session.get_connection()
      end

      def self.handle_argument_error(task, error)
        super
      end

     private

      def pretty_print_cols()
        self.class.pretty_print_cols()
      end
    end

  end
end
