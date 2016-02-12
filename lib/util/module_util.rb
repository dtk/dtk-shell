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
    module ModuleUtil

      NAMESPACE_SEPERATOR = ':'

      def self.resolve_name(module_name, module_namespace)
        is_invalid = module_name.nil? || module_namespace.nil? || module_name.empty? || module_namespace.empty?
        raise DtkError, "Failed to provide module name (#{module_name}) or namespace (#{module_namespace})" if is_invalid
        "#{module_namespace}#{NAMESPACE_SEPERATOR}#{module_name}"
      end

      def self.join_name(module_name, module_namespace)
        module_namespace ? resolve_name(module_name, module_namespace) : module_name
      end

      def self.module_name(module_type)
        module_type.to_s.gsub('_',' ')
      end

      # returns [namespace,name]; namespace can be null if cant determine it
      def self.full_module_name_parts?(name_or_full_module_name)
        if name_or_full_module_name.nil?
          return [nil,nil]
        end
        if name_or_full_module_name =~ Regexp.new("(^.+)#{NAMESPACE_SEPERATOR}(.+$)")
          namespace,name = [$1,$2]
        else
          namespace,name = [nil,name_or_full_module_name]
        end
        [namespace,name]
      end

      def self.filter_module_name(name_or_full_module_name)
        full_module_name_parts?(name_or_full_module_name).last
      end

      def self.check_format!(module_identifier)
        return module_identifier if module_identifier.match(/^[0-9]+$/)
        DtkLogger.instance.debug(caller)
        raise DtkError, "Module name should be in following format NAMESPACE#{NAMESPACE_SEPERATOR}MODULE_NAME" unless module_identifier.match(Regexp.new("^.+#{NAMESPACE_SEPERATOR}.+$"))
      end

      def self.type_to_sym(module_type_s)
        module_type_s.to_s.gsub!(/\_/,'-').to_sym
      end
    end
  end
end