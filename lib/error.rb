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
##
# Application expected errors will be handled trough DtkError. All else will be treaded 
# as Internal Server error. Logs will be added to ~/dtk.log for developers to investigate
# issues more closely.

module DTK
  module Client
    class Error < NameError
    end

   # DtkError is child of Error; so order matters
    require File.expand_path('dtk_error', File.dirname(__FILE__))

    class DSLParsing < Error
      def initialize(base_json_error,file_path=nil)
        super(err_msg(base_json_error,file_path))
      end
      private
      def err_msg(base_json_error,file_path=nil)
        "#{base_json_error}: #{file_path}"
      end

      class JSONParsing < self
      end

      class YAMLParsing < self
      end
    end

    # class DtkValidationError < Error

    #   attr_accessor :skip_usage_info

    #   def initialize(msg, skip_usage_info = false)
    #     @skip_usage_info = skip_usage_info
    #     super(msg)
    #   end
    # end

    class DtkValidationError < Error

      attr_accessor :display_usage_info

      def initialize(msg, display_usage_info = false)
        @display_usage_info = display_usage_info
        super(msg)
      end
    end

    # raise by developers to signal wrong usage of components
    class DtkImplementationError < Error
    end

    class DtkLoginRequiredError < Error
    end

  end
end

module DTK
  module Shell
    class Error < DTK::Client::Error
    end

    class ExitSignal < DTK::Client::Error
    end
  end
end