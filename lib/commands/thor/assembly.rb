module DTK::Client
  class Assembly < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns::ASSEMBLY
    end

    desc "ASSEMBLY-NAME/ID converge", "Converges assembly instance"
    def converge(assembly_id)
      post_body = {
        :assembly_id => assembly_id
      }
      # create
      response = post rest_url("assembly/create_task"), post_body
      return response unless response.ok?
      # execute
      task_id = response.data["task_id"]
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "ASSEMBLY-NAME/ID run-smoketests", "Run smoketests associated with assembly instance"
    def run_smoketests(assembly_id)
      post_body = {
        :assembly_id => assembly_id
      }
      # create smoke test
      response = post rest_url("assembly/create_smoketests_task"), post_body
      return response unless response.ok?
      # execute
      task_id = response.data["task_id"]
      post rest_url("task/execute"), "task_id" => task_id
    end

    #TODO: put in flag to control detail level
    desc "[ASSEMBLY-NAME/ID] list [nodes|components|tasks] [FILTER] [--list]","List asssemblies, or nodes, components, tasks from their assemblies."
    method_option :list, :type => :boolean, :default => false
    def list(*rotated_args)
      #TODO: working around bug where arguments are rotated; below is just temp workaround to rotate back
      assembly_id,about,filter = rotate_args(rotated_args)
      about ||= "none"
      #TODO: need to detect if two args given by list [nodes|components|tasks FILTER
      #can make sure that first arg is not one of [nodes|components|tasks] but these could be names of assembly (although unlikely); so would then need to
      #look at form of FILTER
      response = ""

      post_body = {
        :assembly_id => assembly_id,
        :subtype     => 'instance',
        :about       => about,
        :filter      => filter
      }

      case about
        when "none":
          data_type = DataType::ASSEMBLY
           #TODO: change to post rest_url("assembly/list when update on server side
          response = post rest_url("assembly/list_from_library"), post_body
        when "nodes":
          data_type = DataType::NODE
          response = post rest_url("assembly/list"), post_body
        when "components":
          data_type = DataType::COMPONENT
          response = post rest_url("assembly/list"), post_body
        when "tasks":
          data_type = DataType::TASK
          response = post rest_url("assembly/list"), post_body
        else
          raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
      end

      # set render view to be used
      unless options.list?
        response.render_table(data_type)
      end
      
      return response
    end

    desc "list-smoketests ASSEMBLY-ID","List smoketests on asssembly"
    def list_smoketests(assembly_id)
      post_body = {
        :assembly_id => assembly_id
      }
      post rest_url("assembly/list_smoketests"), post_body
    end

    desc "stage ASSEMBLY-TEMPLATE-ID", "Stage library assembly in target"
    method_option "in-target",:aliases => "-t" ,:type => :numeric, :banner => "TARGET-ID",:desc => "Target (id) to create assembly in" 
    def stage(assembly_template_id)
      post_body = {
        :assembly_template_id => assembly_template_id
      }
      if target_id = options["in-target"]
        post_body.merge!(:target_id => target_id)
      end
      post rest_url("assembly/stage"), post_body
    end

    desc "ASSEMBLY-NAME/ID info", "Return info about assembly instance identified by name/id"
    def info(assembly_id)
      post_body = {
        :assembly_id => assembly_id,
        :subtype => :instance
      }
      post rest_url("assembly/info"), post_body
    end

    desc "delete ASSEMBLY-ID [template]", "Delete assembly instance or template"
    def delete(assembly_id,template_keyword=nil)
      post_body = {
        :assembly_id => assembly_id,
        :subtype => template_keyword ? :template : :instance
      }
      post rest_url("assembly/delete"), post_body
    end

    desc "ASSEMBLY-NAME/ID set ATTRIBUTE-PATTERN VALUE", "Set target assembly attributes"
    def set(pattern,value,assembly_id)
      post_body = {
        :assembly_id => assembly_id,
        :pattern => pattern,
        :value => value
      }
      post rest_url("assembly/set_attributes"), post_body
    end

    desc "stage ASSEMBLY-TEMPLATE-ID", "Stage library assembly in target"
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create assembly in" 
    method_option "name",:aliases => "-n" ,
      :type => :string, 
      :banner => "NAME",
      :desc => "Name for assembly instance"
    def stage(assembly_template_id)
      post_body = {
        :assembly_template_id => assembly_template_id
      }
      if target_id = options["in-target"]
        post_body.merge!(:target_id => target_id)
      end
      if name = options["name"]
        post_body.merge!(:name => name)
      end
      post rest_url("assembly/stage"), post_body
    end

    desc "deploy ASSEMBLY-TEMPLATE-ID", "Deploy assembly from library"
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create assembly in"
    method_option "name",:aliases => "-n" ,
      :type => :string, 
      :banner => "NAME",
      :desc => "Name for assembly instance" 
    def deploy(assembly_template_id)
      post_body = {
        :assembly_template_id => assembly_template_id
      }
      if target_id = options["in-target"]
        post_body.merge!(:target_id => target_id)
      end
      if name = options["name"]
        post_body.merge!(:name => name)
      end
      response = post(rest_url("assembly/stage"),post_body)
      return response unless response.ok?
      assembly_id = response.data["assembly_id"]
      converge(assembly_id)
    end

    desc "create-jenkins-project ASSEMBLY-TEMPLATE-NAME/ID", "Create Jenkins project for assembly template"
    def create_jenkins_project(assembly_nid)
      #require put here so dont necessarily have to install jenkins client gems
      dtk_require_from_base('command_helpers/jenkins_client')
      post_body = {
        :assembly_id => assembly_nid,
        :subtype => :template
      }
      response = post(rest_url("assembly/info"),post_body)
      return response unless response.ok?
      assembly_id,assembly_name = response.data_ret_and_remove!(:id,:display_name)
      JenkinsClient.create_assembly_project?(assembly_name,assembly_id)
      #TODO: right now JenkinsClient wil throw error if problem; better to create an error response
      nil
    end

    desc "ASSEMBLY-NAME/ID remove-component COMPONENT-ID","Removes component from targeted assembly."
    def remove_component(component_id,assembly_id)
      post_body = {
        :assembly_id  => assembly_id,
        :component_id => component_id
      }
      response = post(rest_url("assembly/info"),post_body)
    end
  end
end

