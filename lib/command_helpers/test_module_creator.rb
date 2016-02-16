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
require 'fileutils'
require 'erubis'

module DTK::Client
	class TestModuleCreator
		class << self
			def create_clone(type, module_name)
				Response.wrap_helper_actions do
		      modules_dir = OsUtil.test_clone_location()
		      FileUtils.mkdir_p(modules_dir) unless File.directory?(modules_dir)
		      target_repo_dir = OsUtil.module_location(type,module_name)

		      begin
		      	FileUtils.mkdir_p(target_repo_dir)
		        generate_model(module_name, target_repo_dir)
		        generate_serverspec_files(module_name, target_repo_dir)
		      rescue => e
		      	additional_error_msg = ""
		        error_msg = "Create of directory (#{target_repo_dir}) failed."
		        additional_error_msg = "Directory already exists" if e.message.include? "File exists"
		        raise DTK::ErrorUsage.new(error_msg + " " + additional_error_msg,:log_error=>false)
		      end
		      {"module_directory" => target_repo_dir}
		    end
			end

			def generate_model(module_name, target_repo_dir)
				input = File.expand_path('test_module_templates/dtk.model.yaml.eruby', File.dirname(__FILE__))
				eruby = Erubis::Eruby.new(File.read(input))
				content = eruby.result(:module_name => module_name)
				File.open(target_repo_dir + "/dtk.model.yaml", "w") { |f| f.write(content) }
			end

			def generate_serverspec_files(module_name, target_repo_dir)
				template_location = File.expand_path('test_module_templates', File.dirname(__FILE__))
				spec_helper_template = Erubis::Eruby.new(File.read(template_location + "/spec_helper.rb.eruby")).result
				spec_template = Erubis::Eruby.new(File.read(template_location + "/temp_component_spec.rb.eruby")).result

				begin
					#Create standard serverspec structure
					FileUtils.mkdir_p(target_repo_dir + "/serverspec/spec/localhost")
					File.open(target_repo_dir + "/serverspec/spec/spec_helper.rb", "w") { |f| f.write(spec_helper_template) }
					File.open(target_repo_dir + "/serverspec/spec/localhost/temp_component_spec.rb", "w") { |f| f.write(spec_template) }
				rescue => e
					error_msg = "Generating serverspec files failed."
		      DtkLogger.instance.error_pp(e.message, e.backtrace)
		      raise DTK::ErrorUsage.new(error_msg,:log_error=>false)
				end
			end
		end
	end
end
