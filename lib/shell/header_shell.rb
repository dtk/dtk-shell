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

module DTK
  module Shell

    # We will use this class to generate header for console which would be always present,
    # when activated. Hirb implementation will be used to display status information.

    class HeaderShell

      attr_accessor :active
      alias_method  :is_active?, :active

      def initialize
        @active = true
      end

      def print_header
        puts "*********************"
        puts "********************* #{Time.now} "
        puts "*********************"
      end


    end
  end
end
