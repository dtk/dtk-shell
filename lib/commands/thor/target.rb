dtk_require_common_commands('thor/inventory_parser')
module DTK::Client
  class Target < CommandBaseThor
    include InventoryParserMixin

    def self.pretty_print_cols()
      PPColumns.get(:target)
    end

    def self.alternate_identifiers()
      return ['PROVIDER']
    end

    def self.extended_context()
      {
        :context => {
          # want auto complete for --provider option
          "--provider" => "provider"
        }
      }
    end

    desc "TARGET-NAME/ID list-nodes","Lists node instances in given targets."
    def list_nodes(context_params)
      context_params.method_arguments = ["nodes"]
      list_targets(context_params)
    end

    desc "TARGET-NAME/ID info","Provides information about specified target"
    def info(context_params)
      target_id   = context_params.retrieve_arguments([:target_id!],method_argument_names)

      post_body = {:target_id => target_id}
      response = post rest_url('target/info'), post_body
      response.render_custom_info("target")
    end

    desc "TARGET-NAME/ID import-nodes --source SOURCE","Reads from inventory dsl and populates the node instance objects (SOURCE: file:/path/to/file.yaml)."
    method_option :source, :type => :string
    def import_nodes(context_params)
      target_id   = context_params.retrieve_arguments([:target_id!],method_argument_names)
      source = context_params.retrieve_thor_options([:source!], options)
      parsed_source = source.match(/^(\w+):(.+)/)
      import_type = parsed_source[1]
      path = parsed_source[2]
      
      raise DTK::Client::DtkValidationError, "We do not support '#{import_type}' as import source at the moment. Valid sources: #{ValidImportTypes}" unless ValidImportTypes.include?(import_type)

      post_body = {:target_id => target_id}

      if import_type.eql?('file')
        inventory_data = parse_inventory_file(path)
        post_body.merge!(:inventory_data => inventory_data)
      end

      # raise
      
      response  = post rest_url("target/import_nodes"), post_body
      return response unless response.ok?

      if response.data.empty?
        OsUtil.print("No new nodes to import!", :yellow)
      else
        OsUtil.print("Successfully imported nodes:", :yellow)
        response.data.each do |node|
          OsUtil.print("#{node}", :yellow)
        end
      end
    end
    ValidImportTypes = ["file"]

    desc "TARGET-NAME/ID import-nodes --source SOURCE","Install node agents on imported physical nodes."
    def install_agents(context_params)
      target_id   = context_params.retrieve_arguments([:target_id!],method_argument_names)

      post_body = {:target_id => target_id}
      post rest_url("target/install_agents"), post_body
    end

    desc "create-target [TARGET-NAME] --provider PROVIDER --region REGION", "Create target based on given provider"
    method_option :provider, :type => :string
    method_option :region, :type => :string
    def create_target(context_params)
      # we use :target_id but that will retunr provider_id (another name for target template ID)
      target_name = context_params.retrieve_arguments([:option_1],method_argument_names)
      region   = context_params.retrieve_thor_options([:region!], options)
      provider = context_params.retrieve_thor_options([:provider!], options)

      DTK::Shell::InteractiveWizard.validate_region(region)

      post_body = {
        :provider_id => provider,
        :region => region
      }
      post_body.merge!(:target_name => target_name) if target_name
      response = post rest_url("target/create"), post_body
      @@invalidate_map << :target

      return response
    end

    desc "create-target [TARGET-NAME] --provider PROVIDER --region REGION", "Create target based on given provider"
    method_option :region, :type => :string
    method_option :provider, :type => :string
    def create_target(context_params)
      # we use :target_id but that will retunr provider_id (another name for target template ID)
      target_name = context_params.retrieve_arguments([:option_1],method_argument_names)
      region   = context_params.retrieve_thor_options([:region!], options)
      provider = context_params.retrieve_thor_options([:provider!], options)

      DTK::Shell::InteractiveWizard.validate_region(region)

      post_body = {
        :provider_id => provider,
        :region => region
      }
      post_body.merge!(:target_name => target_name) if target_name
      response = post rest_url("target/create"), post_body
      @@invalidate_map << :target

      return response
    end

    desc "create-target [TARGET-NAME] --provider PROVIDER --region REGION", "Create target based on given provider"
    method_option :provider, :type => :string
    method_option :region, :type => :string
    def create_target(context_params)
      # we use :target_id but that will retunr provider_id (another name for target template ID)
      target_name = context_params.retrieve_arguments([:option_1],method_argument_names)
      region   = context_params.retrieve_thor_options([:region!], options)
      provider = context_params.retrieve_thor_options([:provider!], options)

      DTK::Shell::InteractiveWizard.validate_region(region)

      post_body = {
        :provider_id => provider,
        :region => region
      }
      post_body.merge!(:target_name => target_name) if target_name
      response = post rest_url("target/create"), post_body
      @@invalidate_map << :target

      return response
    end

    desc "create-target [TARGET-NAME] --provider PROVIDER --region REGION", "Create target based on given provider"
    method_option :region, :type => :string
    method_option :provider, :type => :string
    def create_target(context_params)
      # we use :target_id but that will retunr provider_id (another name for target template ID)
      target_name = context_params.retrieve_arguments([:option_1],method_argument_names)
      region   = context_params.retrieve_thor_options([:region!], options)
      provider = context_params.retrieve_thor_options([:provider!], options)

      DTK::Shell::InteractiveWizard.validate_region(region)

      post_body = {
        :provider_id => provider,
        :region => region
      }
      post_body.merge!(:target_name => target_name) if target_name
      response = post rest_url("target/create"), post_body
      @@invalidate_map << :target

      return response
    end

    desc "TARGET-NAME/ID list-services","Lists service instances in given targets."
    def list_services(context_params)
      context_params.method_arguments = ["assemblies"]
      list_targets(context_params)
    end


    def self.validation_list(context_params)
      provider_id = context_params.retrieve_arguments([:provider_id])

      if provider_id
        # if assembly_id is present we're loading nodes filtered by assembly_id
        post_body = {
          :subtype   => :instance,
          :parent_id => provider_id
        }

        response = get_cached_response(:provider_target, "target/list", post_body)
      else
        # otherwise, load all nodes
        response = get_cached_response(:target, "target/list", { :subtype => :instance })
      end

      response
    end

    desc "list-targets","Lists available targets."
    def list_targets(context_params)
      provider_id, target_id, about = context_params.retrieve_arguments([:provider_id, :target_id, :option_1],method_argument_names||="")

      if target_id.nil?
        post_body = { 
          :subtype   => :instance,
          :parent_id => provider_id
        }
        response  = post rest_url("target/list"), post_body
           
        response.render_table(:target)
      else
        post_body = {
          :target_id => target_id,
          :about => about
        }

        case about
          when "nodes"
            response  = post rest_url("target/info_about"), post_body
            data_type =  :node
          when "assemblies"
            post_body.merge!(:detail_level => 'nodes', :include_workspace => true)
            response  = post rest_url("target/info_about"), post_body
            data_type =  :assembly
          else
            raise_validation_error_method_usage('list')
        end

        response.render_table(data_type)
      end
    end

    desc "delete-target TARGET-IDENTIFIER","Deletes target or provider"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_target(context_params)
      target_id   = context_params.retrieve_arguments([:option_1!],method_argument_names)

      # No -y options since risk is too great
      return unless Console.confirmation_prompt("Are you sure you want to delete target '#{target_id}' (all assemblies/nodes that belong to this target will be deleted as well)'"+'?')
     
      post_body = {
        :target_id => target_id
      }

      @@invalidate_map << :target

      return post rest_url("target/delete"), post_body
    end
  end
end
