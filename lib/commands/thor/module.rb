#TODO: deprecate after making sure move/change wants necessary to module-component; coudl also consider making 'module' alias for 'module-component'
#TODO: may be consistent on whether component module id or componnet module name used as params
dtk_require_from_base('command_helpers/ssh_processing')
dtk_require_from_base('command_helpers/git_repo')
module DTK::Client
  class Module < CommandBaseThor
    def self.pretty_print_cols()
      PPColumns::MODULE
    end
    desc "list [--remote]","List library or remote component modules"
    method_option :list, :type => :boolean, :default => false
    method_option :remote, :type => :boolean, :default => false
    def list()
      if options.remote?
        data_type = DataType::REMOTE_MODULE
        response = post rest_url("component_module/list_remote")
      else
        data_type = DataType::MODULE
        response = post rest_url("component_module/list_from_library")
      end

      # set render view to be used
      response.render_table(data_type) unless options.list?
      return response
    end

    # TODO: See if we are deleting this
    desc "import REMOTE-MODULE-NAME[,REMOTE-MODULE-NAME2..] [library_id]", "Import remote module(s) into library"
    def import(module_name_x,library_id=nil)
      module_names = module_name_x.split(",")
      if module_names.size > 1
        return module_names.map{|module_name|import(module_name,library_id)}
      end
      module_name = module_names.first
      post_body = {
       :remote_module_name => module_name
      }
      post_body.merge!(:library_id => library_id) if library_id
      post rest_url("component_module/import"), post_body
    end

    desc "export COMPONENT-MODULE-NAME/ID", "Export component module to remote repo"
    def export(component_module_id,library_id=nil)
      post_body = {
       :component_module_id => component_module_id
      }
      post rest_url("component_module/export"), post_body
    end

    desc "push-all-changes", "Push changes from local copy of module to server"
    def push_all_changes()
      diffs = GitRepo.push_all_changes(:component_module)
      #TODO: if any changes tell the server to synchronize the mode with that 
      #post to component_module/update_meta_info"
      diffs
    end

    desc "update-library COMPONENT-MODULE-ID", "Updates library module with workspace module"
    def update_library(component_module_id)
      post_body = {
       :component_module_id => component_module_id
      }
      post rest_url("component_module/update_library"), post_body
    end

    desc "revert-workspace COMPONENT-MODULE-ID", "Revert workspace (discarding changes) to library version"
    def revert_workspace(component_module_id)
      post_body = {
       :component_module_id => component_module_id
      }
      post rest_url("component_module/revert_workspace"), post_body
    end
  end
end

