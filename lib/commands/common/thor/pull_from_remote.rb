#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
module DTK::Client
  module PullFromRemoteMixin
    def pull_from_remote_aux(module_type,module_id,opts={})
      version = opts[:version]
      remote_namespace = opts[:remote_namespace]
      #get remote module info, errors raised if remote is not linked or access errors
      path_to_key = SSHUtil.default_rsa_pub_key_path()
      rsa_pub_key = File.file?(path_to_key) && File.open(path_to_key){|f|f.read}.chomp

      post_body = PostBody.new(
        PullFromRemote.id_field(module_type) => module_id,
        :access_rights => "r",
        :action => "pull",
        :version? => version,
        :remote_namespace? => remote_namespace,
        :rsa_pub_key? => rsa_pub_key
      )
      response = post(rest_url("#{module_type}/get_remote_module_info"),post_body)
      return response unless response.ok?

      module_name,full_module_name, frozen = response.data(:module_name, :full_module_name, :frozen)
      raise DtkError, "You are not allowed to update frozen #{module_type} versions!" if frozen

      remote_params = response.data_hash_form(:remote_repo_url,:remote_repo,:remote_branch)
      remote_params.merge!(:version => version) if version

      # check and import component module dependencies before importing service itself
      unless opts[:skip_recursive_pull]
        import_module_component_dependencies(module_type, module_id, remote_namespace)
      end

      # check whether a local module exists to determine whether pull from local clone or try to pull from server
      # TODO: probably remove OsUtil.print("Pulling changes from remote: #{remote_params[:remote_repo]} @ #{remote_params[:remote_repo_url]}")

      if Helper(:git_repo).local_clone_dir_exists?(module_type, module_name, :full_module_name => full_module_name, :version => version)
        unless rsa_pub_key
          raise DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
        end
        opts_perform_locally = remote_params.merge(
          :full_module_name => full_module_name,
          :force => opts[:force],
          :do_not_raise => opts[:do_not_raise],
          :ignore_dependency_merge_conflict => opts[:ignore_dependency_merge_conflict]
        )
        PullFromRemote.perform_locally(self,module_type,module_id,module_name,opts_perform_locally)
      else
        # TODO: see if this works correctly
        PullFromRemote.perform_on_server(self,module_type,module_id,full_module_name,remote_params)
      end
    end

   private

    ##
    #
    # module_type: will be :component_module or :service_module
    def import_module_component_dependencies(module_type, module_id, remote_namespace = nil)
      response = resolve_pull_from_remote_on_server(module_type, module_id, remote_namespace)

      print "Resolving dependencies please wait ... "
      RemoteDependencyUtil.check_permission_warnings(response)

      # install them all!
      if (response.ok? && !(missing_components = response.data(:missing_modules)).empty?)
        required_modules = response.data(:required_modules)
        puts " New dependencies found, Installing."

        trigger_module_auto_import(missing_components, required_modules, { :include_pull_action => true })

        puts "Resuming pull from remote ..."
      else
        puts 'Done.'
      end

      # pull them all!
      if (response.ok? && !(required_modules = response.data(:required_modules)).empty?)
        trigger_module_auto_pull(required_modules)
      end

      RemoteDependencyUtil.print_dependency_warnings(response)
      nil
    end

  private

    def resolve_pull_from_remote_on_server(module_type, module_id, remote_namespace=nil)
      post_body = PostBody.new(
        :module_id => module_id,
        :remote_namespace? => remote_namespace,
        :rsa_pub_key => SSHUtil.rsa_pub_key_content()
      )
      post(rest_url("#{module_type}/resolve_pull_from_remote"),post_body)
    end

    module PullFromRemote
      extend CommandBase
      def self.perform_locally(cmd_obj,module_type,module_id,module_name,remote_params)
        opts = remote_params
        response = cmd_obj.Helper(:git_repo).pull_changes(module_type,module_name,opts)

        # return response unless response.ok?
        if custom_message = response.data[:custom_message]
          puts custom_message
        elsif (response.data[:diffs].nil? || response.data[:diffs].empty?)
          puts "No changes to pull from remote.".colorize(:yellow) unless response['errors']
        else
          puts "Changes pulled from remote".colorize(:green)
        end

        response
      end

      def self.perform_on_server(cmd_obj,module_type,module_id,module_name,remote_params)
        #TODO: this does not handle different namespaces; so suggesting workaround for now
        raise DtkError, "Module must be cloned to perform this operation; execute 'clone' command and then retry."
        post_body = {
          id_field(module_type) => module_id,
          :remote_repo => remote_params[:remote_repo],
          :module_name => module_name
        }
        post_body.merge!(:version => remote_params[:version]) if remote_params[:version]
        response = post rest_url("#{module_type}/pull_from_remote"), post_body


        puts "You have successfully pulled code on server instance." if response.ok?
        response
      end

      def self.id_field(module_type)
        "#{module_type}_id"
      end

    end
  end
end
