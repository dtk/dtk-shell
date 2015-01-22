module DTK::Client
  module PurgeCloneMixin
    def purge_clone_aux(module_type,opts={})
      module_name = opts[:module_name]
      version = opts[:version]
      opts_module_loc = (opts[:assembly_module] ? {:assembly_module => opts[:assembly_module]} : Hash.new)
      module_location = OsUtil.module_location(module_type,module_name,version,opts_module_loc)
      dirs_to_delete = [module_location]
      if opts[:delete_all_versions]
        dirs_to_delete += OsUtil.module_version_locations(module_type,module_name,version,opts)
      end
      response = Response::Ok.new()
      pwd = Dir.getwd()
      dirs_to_delete.each do |dir|
        if File.directory?(dir)
          if ((pwd == dir) || (pwd.include?("#{dir}/")))
            OsUtil.print("Local directory '#{dir}' is not deleted because it is your current working directory.", :yellow)
          else
            FileUtils.rm_rf(dir)
          end
        end
      end
      response
    end

    def check_if_unsaved_cmp_module_changes(assembly_or_workspace_id, opts={})
      unsaved_modules = []
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :subtype     => 'instance'
      }
      response = post rest_url("assembly/get_component_modules"), post_body

      if response.ok?
        response.data.each do |cmp_mod|
          branch_relationship = cmp_mod['branch_relationship']||''
          unsaved_modules << "#{cmp_mod['namespace_name']}:#{cmp_mod['display_name']}" if (cmp_mod['local_copy_diff'] && branch_relationship.eql?('local_ahead'))
        end
      end

      unsaved_modules
    end

    def check_if_unsaved_assembly_changes(assembly_or_workspace_id, assembly_name, opts={})
      post_body = {
        :assembly_id => assembly_or_workspace_id,
        :module_type => 'service_module',
        :modification_type => 'workflow'
      }
      response = post rest_url("assembly/prepare_for_edit_module"), post_body
      return unless response.ok?
      assembly_name,service_module_id,service_module_name,version,repo_url,branch,branch_head_sha,edit_file = response.data(:assembly_name,:module_id,:full_module_name,:version,:repo_url,:workspace_branch,:branch_head_sha,:edit_file)

      edit_opts = {
        :automatically_clone => true,
        :assembly_module => {
          :assembly_name => assembly_name,
          :version => version
        },
        :workspace_branch_info => {
          :repo_url => repo_url,
          :branch => branch,
          :module_name => service_module_name
        },
        :commit_sha => branch_head_sha,
        :pull_if_needed => true,
        :modification_type => :workflow,
        :edit_file => edit_file
      }

      version = nil #TODO: version associated with assembly is passed in edit_opts, which is a little confusing
      module_location  = OsUtil.module_location(:service_module,service_module_name,version,edit_opts)
      return unless File.directory?(module_location)

      grit_adapter = Helper(:git_repo).create(module_location)
      return unless grit_adapter.repo_exists?

      grit_adapter.changed?
    end

  end
end
