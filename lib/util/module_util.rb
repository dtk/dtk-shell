module DTK
  module Client
    module ModuleUtil

      NAMESPACE_SEPERATOR = '::'

      def self.resolve_name(module_name, module_namespace)
        is_invalid = module_name.nil? || module_namespace.nil? || module_name.empty? || module_namespace.empty?
        raise DtkError, "Failed to provide module name (#{module_name}) or namespace (#{module_namespace})" if is_invalid
        "#{module_namespace}#{NAMESPACE_SEPERATOR}#{module_name}"
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

      def self.check_format!(module_identifier)
        return module_identifier if module_identifier.match(/^[0-9]+$/)
        raise DtkError, "Module name should be in following format NAMESPACE::MODULE_NAME" unless module_identifier.match(/^.+::.+$/)
      end
    end
  end
end
