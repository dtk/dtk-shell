module DTK::Client
  class ModuleComponent < CommandBaseThor

    desc "COMPONENT-MODULE-NAME/ID info", "Get information about given component module."
    def info(component_module_id)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/info"), post_body
    end

    desc "[COMPONENT-MODULE-NAME/ID] list [component] [--remote]", "List all components for given component module."
    method_option :list, :type => :boolean, :default => false
    method_option :remote, :type => :boolean, :default => false
    def list(targets='none', component_module_id=nil)
      post_body = {
        :component_module_id => component_module_id,
        :about => targets
      }

      case targets
      when 'none'
        action = (options.remote? ? "list_remote" : "list")
        response = post rest_url("component_module/#{action}")
        data_type = DataType::COMPONENT
      when 'components'
        if options.remote?
          #TODO: this is temp; will shortly support this
          raise DTK::Client::DtkError, "Not supported '--remote' option when listing components in component modules"
        end
        response = post rest_url("component_module/list"), post_body
        data_type = DataType::COMPONENT
      else
        raise DTK::Client::DtkError, "Not supported type '#{targets}' for given command."
      end

      response.render_table(data_type) unless options.list?

      return response
    end

    desc "COMPONENT-MODULE-NAME/ID delete", "Delete component module and all items contained in it"
    def delete(component_module_id)
      post_body = {
       :component_module_id => component_module_id
      }
      post rest_url("component_module/delete"), post_body
    end

    desc "COMPONENT-MODULE-NAME/ID promote-to-library [VERSION]", "Update library module with chyanges from workspace"
    def promote_to_library(arg1,arg2=nil)
      #component_module_id is in last position, which coudl be arg1 or arg2
      component_module_id,version = (arg2 ? [arg2,arg1] : [arg1])

      post_body = {
        :component_module_id => component_module_id
      }
      post_body.merge!(:version => version) if version

      post rest_url("component_module/promote_to_library"), post_body
    end

    #TODO: may also provide an optional library argument to create in new library
    desc "COMPONENT-MODULE-NAME/ID create-new-version [EXISTING-VERSION] NEW-VERSION", "Create new version of module in library from workspace"
    def create_new_version(arg1,arg2,arg3=nil)
      #component_module_id is in last position
      component_module_id,new_version,existing_version = 
        (arg3 ? [arg3,arg2,arg1] : [arg2,arg1])

      post_body = {
        :component_module_id => component_module_id,
        :new_version => new_version
      }
      if existing_version
        post_body.merge!(:existing_version => existing_version)
      end

      post rest_url("component_module/create_new_version"), post_body
    end

    desc "COMPONENT-MODULE-NAME/ID export", "Export component module remote repository."
    def export(component_module_id)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/export"), post_body
    end

    desc "COMPONENT-MODULE-NAME/ID push-to-remote", "Push local copy of component module to remote repository."
    def push_to_remote(component_module_id)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/push_to_remote"), post_body
    end

    desc "COMPONENT-MODULE-NAME/ID pull-from-remote", "Update local component module from remote repository."
    def pull_from_remote(component_module_id)
      post_body = {
        :component_module_id => component_module_id
      }

      post rest_url("component_module/pull_from_remote"), post_body
    end

    # we make valid methods to make sure that when context changing
    # we allow change only for valid ID/NAME

    no_tasks do
      def self.valid_id?(value, conn)
        @conn = conn if @conn.nil?
        response = post rest_url("component_module/list")
        unless response.nil?
          response['data'].each do |element|
            return true if (element['id'].to_s==value || element['display_name'].to_s==value)
          end
        end
        return false
      end
    end

  end
end

