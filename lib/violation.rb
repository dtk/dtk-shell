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
    class Violation
      dtk_require('violation/attribute')
      dtk_require('violation/fix')
      
      # fix must be before the specific violations
      dtk_require('violation/required_unset_attribute')
      dtk_require('violation/illegal_attribute_value')
      
      def self.fix_violations(violation_hash_array)
        violation_objects = violation_hash_array.map { |violation_hash| Violation.create?(violation_hash) }.compact
        run_fix_wizard(violation_objects) unless violation_objects.empty?
      end
      
      private
      
      def self.create?(violation_hash)
        unless violation_type = violation_hash['type']
          DtkLogger.error "No type in violation hash: #{violation_hash.inspect}"
          return nil
        end

        case violation_type
         when 'required_unset_attribute'
          RequiredUnsetAttribute.new(violation_hash)
         when 'illegal_attribute_value'
          IllegalAttributeValue.new(violation_hash)
         else
          DtkLogger.error "untreated violation type '#{violation_type}'"
          nil
        end
      end

      def self.run_fix_wizard(violation_objects)
        violation_objects.each do |violation| 
          result = process_until_fixed_or_skipped(violation) 
          return if result.skip_all?
        end
      end

      def self.process_until_fixed_or_skipped(violation)
        result = violation.get_input_and_appy_fix
        if result.ok? or result.skip_current? or result.skip_all?
          result
        else
          process_until_fixed_or_skipped(violation) 
        end
      end

    end
  end
end

