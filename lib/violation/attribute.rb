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
  class Violation
    # represents a component, node, or assembly attribute
    class Attribute
      def initialize(attribute_hash)
        # ref is the only key that is guarenteed to be present
        @ref          = attribute_hash['ref']
        @datatype     = attribute_hash['datatype']
        @hidden       = attribute_hash['hidden']
        @legal_values = attribute_hash['legal_values']
        @fix_text     = attribute_hash['fix_text'] 
      end

      def prompt_user_for_value
        Shell::InteractiveWizard.prompt_user_for_value(fix_text)
      end

      def illegal_value?(value)
        value_does_not_match_datatype?(value) or value_not_legal_type?(value)
      end

      def set_and_propagate_value(value)
        # TODO: stub
      end

      private
      
      def fix_text
        @fix_text ||= "Enter value for attribute '#{@ref}'"
      end

      def value_does_not_match_datatype?(value)
        if @datatype
          # TODO: put in datatype test
        end
      end

      def value_not_legal_type?(value)
        if @legal_values
          ! @legal_values.include?(value)
        end
      end

    end
  end
end


