module DTK::Client
  class Assembly < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:assembly)
    end

    desc "ASSEMBLY-NAME/ID promote-to-library", "Update or create library assembly using workspace assembly"
    def promote_to_library(assembly_id)
      post_body = {
        :assembly_id => assembly_id
      }

      post rest_url("assembly/promote_to_library"), post_body
    end

    desc "ASSEMBLY-NAME/ID create-new-template SERVICE-MODULE-NAME ASSEMBLY-TEMPLATE-NAME", "Create a new assembly template from workspace assembly" 
    def create_new_template(arg1,arg2,arg3)
      #assembly_id is in last position
      assembly_id,service_module_name,assembly_template_name = [arg3,arg1,arg2]
      post_body = {
        :assembly_id => assembly_id,
        :service_module_name => service_module_name,
        :assembly_template_name => assembly_template_name
      }
      post rest_url("assembly/create_new_template"), post_body
    end

    desc "ASSEMBLY-NAME/ID converge [-m COMMIT-MSG]", "Converges assembly instance"
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def converge(assembly_id)
      # create task
      post_body = {
        :assembly_id => assembly_id
      }
      post_body.merge!(:commit_msg => options["commit_msg"]) if options["commit_msg"]

      response = post rest_url("assembly/create_task"), post_body
      return response unless response.ok?

      # execute task
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "ASSEMBLY-NAME/ID task-status", "Task status of running or last assembly task"
    def task_status(assembly_id)
      post_body = {
        :assembly_id => assembly_id
      }
      response = post rest_url("assembly/task_status"), post_body
      response.set_datatype(:task)
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
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "list","List asssembly instances"
    method_option :list, :type => :boolean, :default => false
    def list()
      data_type = :assembly
      response = post rest_url("assembly/list"), {:subtype  => 'instance'}

      # set render view to be used
      unless options.list?
        response.render_table(data_type)
      end
     
      response
    end

    #TODO: put in flag to control detail level
    desc "ASSEMBLY-NAME/ID show nodes|components|tasks [FILTER] [--list]","List nodes, components, or tasks associated with assembly."
    method_option :list, :type => :boolean, :default => false
    def show(*rotated_args)
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
        when "nodes":
          data_type = :node
          response = post rest_url("assembly/info_about"), post_body
        when "components":
          data_type = :component
          response = post rest_url("assembly/info_about"), post_body
        when "attributes":
          data_type = :attribute
          response = post rest_url("assembly/info_about"), post_body
        when "tasks":
          data_type = :task
          response = post rest_url("assembly/info_about"), post_body
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

    desc "ASSEMBLY-NAME/ID info", "Return info about assembly instance identified by name/id"
    def info(assembly_id)
      post_body = {
        :assembly_id => assembly_id,
        :subtype => :instance
      }
      post rest_url("assembly/info"), post_body
    end

    desc "delete-and-destroy ASSEMBLY-ID", "Delete assembly instance, termining any nodes taht have been spun up"
    def delete_and_destroy(assembly_id)
      post_body = {
        :assembly_id => assembly_id,
        :subtype => :instance
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
      assembly_id,assembly_name = response.data_ret!(:id,:display_name)
      #TODO: modify JenkinsClient to use response wrapper
      JenkinsClient.create_assembly_project?(assembly_name,assembly_id)
      nil
    end

    desc "ASSEMBLY-NAME/ID remove-component COMPONENT-ID","Removes component from targeted assembly."
    def remove_component(component_id,assembly_id)
      post_body = {
        :id => component_id
      }
      response = post(rest_url("component/delete"),post_body)
    end


    desc "ASSEMBLY-NAME/ID get-netstats", "Get netstats"
    def get_netstats(assembly_id)
      post_body = {
        :assembly_id => assembly_id
      }
      post(rest_url("assembly/get_netstats"),post_body)
    end

    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:assembly, "assembly/list")
        
        unless response.nil?
          response['data'].each do |element|
            return true if (element['id'].to_s==value || element['display_name'].to_s==value)
          end
        end
        return false
      end

      def self.get_identifiers(conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:assembly, "assembly/list")

        unless response.nil?
          identifiers = []
          response['data'].each do |element|
             identifiers << element['display_name']
          end
          return identifiers
        end
        return []
      end
    end
    
  end
end

