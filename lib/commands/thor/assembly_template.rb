dtk_require("../../shell/status_monitor")

module DTK::Client
  class AssemblyTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:assembly_template)
    end

    desc "ASSEMBLY-TEMPLATE-NAME/ID info", "Get information about given assembly template."
    method_option :list, :type => :boolean, :default => false
    def info(assembly_id=nil)
      data_type = :assembly_template

      post_body = {
        :assembly_id => assembly_id,
        :subtype => 'template',
      }
      post rest_url("assembly/info"), post_body
    end

    desc "list", "List all assembly templates."
    def list()
      response = post rest_url("assembly/list"), {:subtype => 'template'}
      data_type = :assembly_template
      response.render_table(data_type) 
    end

#    desc "[ASSEMBLY-TEMPLATE-NAME/ID] show [nodes|components|targets]", "List all nodes/components/targets for given assembly template."
    #TODO: temporaily taking out target option
    desc "ASSEMBLY-TEMPLATE-NAME/ID show nodes|components", "List all nodes/components for given assembly template."
    method_option :list, :type => :boolean, :default => false
    def show(arg1,arg2)
      assembly_id, about = [arg2,arg1] 

      post_body = {
        :assembly_id => assembly_id,
        :subtype => 'template',
        :about => about
      }

      case about
      when 'nodes'
        response = post rest_url("assembly/info_about"), post_body
        data_type = :node_template
      when 'components'
        response = post rest_url("assembly/info_about"), post_body
        data_type = :component
=begin
      when 'targets'
        response = post rest_url("assembly/info_about"), post_body
        data_type = :target
=end
      else
        raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
      end

      response.render_table(data_type) unless options.list?

      response
    end

    desc "ASSEMBLY-TEMPLATE-NAME/ID stage [INSTANCE-NAME]", "Stage assembly template in target."
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create assembly in" 
    def stage(arg1,arg2=nil)
      assembly_id,name = (arg2.nil? ? [arg1] : [arg2,arg1])

      post_body = {
        :assembly_id => assembly_id
      }
      post_body.merge!(:target_id => options["in-target"]) if options["in-target"]
      post_body.merge!(:name => name) if name
      post rest_url("assembly/stage"), post_body
    end

    desc "ASSEMBLY-TEMPLATE-NAME/ID deploy [INSTANCE-NAME] [-m COMMIT-MSG]", "Stage and deploy assembly template in target."
    method_option "in-target",:aliases => "-t" ,
      :type => :numeric, 
      :banner => "TARGET-ID",
      :desc => "Target (id) to create assembly in" 
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def deploy(arg1,arg2=nil)
      assembly_template_id,name = (arg2.nil? ? [arg1] : [arg2,arg1])

      response = stage(arg1,arg2)
      return response unless response.ok?

      # create task      
      assembly_id = response.data(:assembly_id)
      post_body = {
        :assembly_id => assembly_id,
        :commit_msg => options["commit_msg"]||"Initial deploy"
      }

      ret = response = post(rest_url("assembly/create_task"), post_body)
      return response unless response.ok?

      # execute task
      task_id = response.data(:task_id)
      response = post(rest_url("task/execute"), "task_id" => task_id)

      # start watching task ID
      if $shell_mode
        DTK::Shell::StatusMonitor.start_monitoring(task_id) if response.ok?
      end

      return response unless response.ok?
      ret.add_data_value!(:task_id,task_id)
    end


    desc "delete ASSEMBLY-NAME/ID", "Delete assembly template"
    def delete(assembly_id)
      # Ask user if really want to delete assembly-template, if not then return to dtk-shell without deleting
      return unless confirmation_prompt("Are you sure you want to delete assembly-template '#{assembly_id}'?")

      post_body = {
        :assembly_id => assembly_id,
        :subtype => :template
      }
      post rest_url("assembly/delete"), post_body
    end

    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:assembly_template, "assembly/list", {:subtype => 'template'})

        unless (response.nil? || response.empty?)
          unless response['data'].nil?
            response['data'].each do |element|
              return true if (element['id'].to_s==value || element['display_name'].to_s==value)
            end
          end
          
          # if response is ok but response['data'] is nil, display warning message
          DtkLogger.instance.warn("Response data is nil, please check if your request is valid.")
        end
        return false
      end

      def self.get_identifiers(conn)
        @conn    = conn if @conn.nil?
        response = get_cached_response(:assembly_template, "assembly/list", {:subtype => 'template'})

        unless (response.nil? || response.empty?)
          unless response['data'].nil?
            identifiers = []
            response['data'].each do |element|
               identifiers << element['display_name']
            end
            return identifiers
          end

          # if response is ok but response['data'] is nil, display warning message
          DtkLogger.instance.warn("Response data is nil, please check if your request is valid.")
        end

        return []
      end
    end

  end
end

