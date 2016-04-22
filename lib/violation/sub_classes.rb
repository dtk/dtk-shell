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
    class IllegalAttributeValue < self
      def initialize(violation_hash)
        super
        @attribute = Attribute.new(violation_hash['attribute'])
      end

      def get_input_and_apply_fix
        Fix::SetAttribute.get_input_and_apply_fix(@attribute)
      end
    end

    class RequiredUnsetAttribute < self
      def initialize(violation_hash)
        super
        @attribute = Attribute.new(violation_hash['attribute'])
      end

      def get_input_and_apply_fix
        Fix::SetAttribute.get_input_and_apply_fix(@attribute)
      end

    end

    class InvalidCredentials < self
      def initialize(violation_hash)
        super
        @attributes = violation_hash['fix_hashes'].map { |hash|  Attribute.new(hash['attribute']) } 
      end

      def get_input_and_apply_fix
        result = nil
        @attributes.each do |attribute| 
          result = Fix::SetAttribute.get_input_and_apply_fix(attribute)
          return result if result.skip_all? or result.error?
        end
        result.ok? ? Fix::Result.rerun_violation_check : result
      end
    end
  end
end

