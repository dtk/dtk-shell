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
require 'yaml'

module DTK::Client
  module ReparseMixin
    YamlDTKMetaFiles = ['dtk.model.yaml', 'module_refs.yaml', 'assemblies/*.yaml', 'assemblies/*/assembly.yaml']

    def reparse_aux(location)
      files_yaml = YamlDTKMetaFiles.map{|rel_path|Dir.glob("#{location}/#{rel_path}")}.flatten(1)
      files_yaml.each do |file|
        file_content = File.open(file).read
        begin 
          YAML.load(file_content)
        rescue Exception => e
          e.to_s.gsub!(/\(<unknown>\)/,'')
          raise DTK::Client::DSLParsing::YAMLParsing.new("YAML parsing error #{e} in file", file)
        end
      end
      
      Response::Ok.new()
    end

  end
end