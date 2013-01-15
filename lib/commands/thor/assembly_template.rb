dtk_require("../../shell/status_monitor")

module DTK::Client
  class AssemblyTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:assembly_template)
    end

    def self.whoami()
      return :assembly_template, "assembly/list", {:subtype => 'template'}
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

#    desc "[ASSEMBLY-TEMPLATE-NAME/ID] show [nodes|components|targets]", "List all nodes/components/targets for given assembly template."
    #TODO: temporaily taking out target option
    desc "[ASSEMBLY-TEMPLATE-NAME/ID] list [nodes|components]", "List all nodes/components for given assembly template."
    method_option :list, :type => :boolean, :default => false
    def list(*rotated_args)
      if (rotated_args.size == 0)
        post_body = {
          :subtype => 'template',
          :detail_level => 'nodes'
        }
        response = post rest_url("assembly/list"), post_body
        data_type = :assembly_template
        response.render_table(data_type)
      else
        assembly_id, about = rotate_args(rotated_args)

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
      response = post rest_url("assembly/stage"), post_body
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly

      return response
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

      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly

      return ret
    end


    desc "delete ASSEMBLY-NAME/ID", "Delete assembly template"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete(assembly_id)
      unless options.force?
        # Ask user if really want to delete assembly-template, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete assembly-template '#{assembly_id}'"+'?')
      end

      post_body = {
        :assembly_id => assembly_id,
        :subtype => :template
      }
      response = post rest_url("assembly/delete"), post_body
      
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly_template
      return response unless response.ok?
      module_name,branch = response.data(:module_name,:workspace_branch)
      Helper(:git_repo).pull_changes?(:service_module,module_name,:local_branch => branch)
    end
  end
end

