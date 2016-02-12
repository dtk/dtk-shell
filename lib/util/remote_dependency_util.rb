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
#
# Managment of remote dependencies detection (print warning) or providing data from local resources
#
module DTK
  module Client
    module RemoteDependencyUtil
      MODULE_REF_FILE = 'module_refs.yaml'

      class << self
        def print_dependency_warnings(response, success_msg = nil, opts = {})
          are_there_warnings = false
          return are_there_warnings if response.nil? || response.data.nil?

          warnings = response.data['dependency_warnings']
          if warnings && !warnings.empty?
            if opts[:ignore_permission_warnings]
              warnings.delete_if { |warning| warning['error_type'].eql?('no_permission') }
              return if warnings.empty?
            end
            print_out "Following warnings have been detected for current module by Repo Manager:\n"
            warnings.each { |w| print_out("  - #{w['message']}") }
            puts
            are_there_warnings = true
          end
          print_out success_msg, :green if success_msg
          are_there_warnings
        end

        def check_permission_warnings(response)
          errors = ''
          dependency_warnings = response.data['dependency_warnings']

          if dependency_warnings && !dependency_warnings.empty?
            no_permissions = dependency_warnings.select { |warning| warning['error_type'].eql?('no_permission') }

            unless no_permissions.empty?
              errors << "\n\nYou do not have (R) permissions for modules:\n\n"
              no_permissions.each { |np| errors << "  - #{np['module_namespace']}:#{np['module_name']} (owner: #{np['module_owner']})\n" }
              errors << "\nPlease contact owner(s) to change permissions for those modules."
            end
          end

          raise DtkError, errors unless errors.empty?
        end

        # check if all dependent modules are frozen; if they are don't display prompt for update
        def check_for_frozen_modules(required_modules)
          return true if required_modules.nil? || required_modules.empty?

          modules_to_update = required_modules.select{ |md| (md['frozen'].nil? || md['frozen'] == false)}
          return modules_to_update.empty?
        end

        def module_ref_content(location)
          abs_location = File.join(location, MODULE_REF_FILE)
          File.exists?(abs_location) ? File.read(abs_location) : nil
        end

        private

        def print_out(message, color=:yellow)
          DTK::Client::OsUtil.print(message, color)
        end
      end
    end
  end
end