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
    module FixViolations
      dtk_require('fix_violations/fix_mixin')
      # fix_mixin must be before violation
      dtk_require('fix_violations/violation')

      def self.fix_violations(violation_hash_array)
        violation_objects = violation_hash_array.map { |violation_hash| Violation.create?(violation_hash) }.compact
        run_fix_wizard(violation_objects) unless violation_objects.empty?
      end

      private

      def self.run_fix_wizard(violation_objects)
        pp [:violation_objects, violation_objects]
      end

    end
  end
end

