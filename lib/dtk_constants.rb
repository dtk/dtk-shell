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

#
# ID for data types
#

class DataType
  ASSEMBLY       = "ASSEMBLY"
  LIBRARY        = "LIBRARY"
  NODE           = "NODE"
  NODE_GROUP     = "NODE_GROUP"
  MODULE         = "MODULE"
  PROJECT        = "PROJECT"
  REPO           = "REPO"  
  SERVICE_MODULE = "SERVICE_MODULE"
  TARGET         = "TARGET"       
  COMPONENT      = "COMPONENT"
  TASK           = "TASK"
end