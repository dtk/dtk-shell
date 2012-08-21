#
# Pretty Print columns constants. 
#
class PPColumns
  ASSEMBLY       = [:display_name, :execution_status, :type, :id, :description, :external_ref]
  LIBRARY        = [:display_name, :id, :description]
  NODE           = [:display_name, :os_type, :type, :id, :description, :external_ref]
  NODE_GROUP     = [:display_name, :type,:id, :description]
  MODULE         = [:display_name, :id, :version]
  PROJECT        = [:display_name, :id, :description]
  REPO           = [:display_name, :id]
  SERVICE_MODULE = [:display_name, :id, :version]
  TARGET         = [:display_name, :id, :description, :type, :iaas_type]
  COMPONENT      = [:display_name, :id, :type, :version, :library]
end