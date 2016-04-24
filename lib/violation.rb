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
      dtk_require('violation/sub_classes')

      def initialize(service_id, violation_hash)
        @service_id  = service_id
        @description = violation_hash['description']
      end
      private :initialize
      
      def self.fix_violations(service_id, violation_hash_array)
        violation_objects = violation_hash_array.map { |violation_hash| Violation.create?(service_id, violation_hash) }.compact
        if violation_objects.empty?
          Fix::Result.ok
        else
          run_fix_wizard(violation_objects) 
        end
      end
      
      private
      
      def self.create?(service_id, violation_hash)
        unless violation_type = violation_hash['type']
          DtkLogger.error "No type in violation hash: #{violation_hash.inspect}"
          return nil
        end

        case violation_type
         when 'required_unset_attribute'
          RequiredUnsetAttribute.new(service_id, violation_hash)
         when 'illegal_attribute_value'
          IllegalAttributeValue.new(service_id, violation_hash)
         when 'invalid_credentials'
          InvalidCredentials.new(service_id, violation_hash)
         else
          DtkLogger.error "untreated violation type '#{violation_type}'"
          nil
        end
      end

      def self.run_fix_wizard(violation_objects)
        rerun_violation_check = false
        violation_objects.each do |violation| 
          result = run_and_repeat_when_error(violation)
          return result if result.skip_all?
          rerun_violation_check = true if result.rerun_violation_check?
        end
        rerun_violation_check ? Fix::Result.rerun_violation_check : Fix::Result.ok
      end

      def self.run_and_repeat_when_error(violation)
        result = violation.get_input_and_apply_fix
        if result.error? 
          result.render_error_msg
          run_and_repeat_when_error(violation) 
        else
          result
        end
      end

    end
  end
end

