module DTK::Client
  class Assembly < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns::ASSEMBLY
    end

    desc "export ASSEMBLY-ID", "Exports assembly instance or template"
    def export(assembly_id)
      post_body = {
        :assembly_id => assembly_id
      }
      post rest_url("assembly/export"), post_body
    end

    desc "converge ASSEMBLY-ID", "Converges assembly instance"
    def converge(assembly_id)
      post_body = {
        :assembly_id => assembly_id
      }
      response = post rest_url("assembly/create_task"), post_body
      return response unless response.ok?
      task_id = response.data["task_id"]
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "run-smoketests ASSEMBLY-ID", "Run smoketests associated with assembly instance"
    def run_smoketests(assembly_id)
      post_body = {
        :assembly_id => assembly_id
      }
      response = post rest_url("assembly/create_smoketests_task"), post_body
      return response unless response.ok?
      task_id = response.data["task_id"]
      post rest_url("task/execute"), "task_id" => task_id
    end

    #TODO: put in flag to control detail level
    desc "list [library|target] [--list]","List asssemblies in library or target"
    method_option :list, :type => :boolean, :default => false
    def list(parent="library")
      response = ""
      case parent
        when "library":
          response = post rest_url("assembly/list_from_library")
        when "target":
          response = post rest_url("assembly/list_from_target"), "detail_level" => ["attributes"]
       else 
        ResponseBadParams.new("assembly container" => parent)
      end

      # set render view to be used
      unless options.list?
        response.render_table(DataType::ASSEMBLY) if DTK::Client::Response === response
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

    desc "info ASSEMBLY-ID [template]", "Return info about assembly instance or template"
    def info(assembly_id,template_keyword=nil)
      post_body = {
        :assembly_id => assembly_id,
        :subtype => template_keyword ? :template : :instance
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

    desc "set ASSEMBLY-ID ATTRIBUTE-PATTERN VALUE", "set target assembly attributes"
    def set(assembly_id,pattern,value)
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
  end
end

