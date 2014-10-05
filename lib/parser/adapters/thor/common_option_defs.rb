module DTK; module Client
  class CommandBaseThor
    module CommonOptionDefs
      module Mixin
        def required_option(key)
          key = key.to_s
          unless options.has_key?(key)
            raise DtkError, "[ERROR] The mandatory option --#{key} is missing" 
          end
          options[key]
        end
      end
      module ClassMixin
        def version_method_option()
          method_option "version",:aliases => "-v",
          :type => :string, 
          :banner => "VERSION",
          :desc => "Version"
        end
      end
    end
  end
end; end
