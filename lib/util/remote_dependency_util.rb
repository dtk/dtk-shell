#
# Managment of remote dependencies detection (print warning) or providing data from local resources
#
module DTK
  module Client
    module RemoteDependencyUtil

      MODULE_REF_FILE = 'module_refs.yaml'

      class << self

        def print_dependency_warnings(response, success_msg=nil)
          return if response.nil? || response.data.nil?
          warnings = response.data['dependency_warnings']
          if warnings && !warnings.empty?
            print_out "Following warnings have been detected for current module by Repo Manager:\n"
            warnings.each { |w| print_out("  - #{w}") }
            puts
          end
          print_out success_msg, :green if success_msg
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