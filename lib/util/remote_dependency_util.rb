#
# Managment of remote dependencies detection (print warning) or providing data from local resources
#
module DTK
  module Client
    module RemoteDependencyUtil

      MODULE_REF_FILE = 'module_refs.yaml'

      class << self

        def print_dependency_warnings(response, success_msg=nil)
          are_there_warnings = false
          return are_there_warnings if response.nil? || response.data.nil?

          warnings = response.data['dependency_warnings']
          if warnings && !warnings.empty?
            print_out "Following warnings have been detected for current module by Repo Manager:\n"
            warnings.each { |w| print_out("  - #{w['message']}") }
            puts
            are_there_warnings = true
          end
          print_out success_msg, :green if success_msg
          are_there_warnings
        end

        def check_permission_warnings(response)
          errors = ""
          dependency_warnings = response.data['dependency_warnings']

          if dependency_warnings && !dependency_warnings.empty?
            no_permissions = dependency_warnings.select{|warning| warning['error_type'].eql?('no_permission')}

            errors << "\n\nYou do not have (R) permissions for modules:\n\n"
            no_permissions.each {|np| errors << "  - #{np['module_namespace']}:#{np['module_name']} (owner: #{np['module_owner']})\n"}
            errors << "\nPlease contact owner(s) to change permissions for those modules."
          end

          raise DtkError, errors unless errors.empty?
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