module DTK
  module Client
    module PermissionUtil
      class << self
        def validate_permissions!(permission_string)
          # matches example: u-rw, ugo+r, go+w
          match = permission_string.match(/^[ugo]+[+\-][rwd]+$/)
          raise DTK::Client::DtkValidationError, "Provided permission expression ('#{permission_string}') is not valid" unless match
          permission_string
        end
      end
    end
  end
end
