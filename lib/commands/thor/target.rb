dtk_require_common_commands('thor/inventory_parser')
dtk_require_common_commands('thor/create_target')
module DTK::Client
  class Target < CommandBaseThor
    include InventoryParserMixin
    include CreateTargetMixin

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
      list(context_params)
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
      raise DTK::Client::DtkValidationError, "Invalid source! Valid source should contain source_type:source_path (e.g. --source file:path/to/file.yaml)." unless parsed_source

      import_type = parsed_source[1]
      path = parsed_source[2]
      
      raise DTK::Client::DtkValidationError, "We do not support '#{import_type}' as import source at the moment. Valid sources: #{ValidImportTypes}" unless ValidImportTypes.include?(import_type)

      post_body = {:target_id => target_id}

      if import_type.eql?('file')
        inventory_data = parse_inventory_file(path)
        post_body.merge!(:inventory_data => inventory_data)
      end
      
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

    desc "set-default-target TARGET-IDENTIFIER","Sets the default target."
    def set_default_target(context_params)
      target_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      post rest_url("target/set_default"), { :target_id => target_id }
    end

    desc "TARGET-NAME/ID install-agents","Install node agents on imported physical nodes."
    def install_agents(context_params)
      target_id   = context_params.retrieve_arguments([:target_id!],method_argument_names)

      post_body = {:target_id => target_id}
      post rest_url("target/install_agents"), post_body
    end

    desc "create-target [TARGET-NAME] --provider PROVIDER --region REGION [--keypair KEYPAIR] [--security-group SECURITY-GROUP(S)]", "Create target based on given provider"
    method_option :provider, :type => :string
    method_option :region, :type => :string
    method_option :keypair, :type => :string
    method_option :security_group, :type => :string, :aliases => '--security-groups'
    def create_target(context_params)
      option_list = [:provider!, :region, :keypair, :security_group]
      response = create_target_aux(context_params,option_list)
      @@invalidate_map << :target
      response
    end


    desc "TARGET-NAME/ID list-services","Lists service instances in given targets."
    def list_services(context_params)
      context_params.method_arguments = ["assemblies"]
      list(context_params)
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

    desc "list","Lists available targets."
    def list(context_params)
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

    desc "TARGET-NAME/ID edit-target [--keypair KEYPAIR] [--security-group SECURITY-GROUP(S)]","Edit keypair or security-group for given target"
    method_option :keypair, :type => :string
    method_option :security_group, :type => :string, :aliases => '--security-groups'
    def edit_target(context_params)
      target_id   = context_params.retrieve_arguments([:target_id!],method_argument_names)
      keypair, security_group = context_params.retrieve_thor_options([:keypair, :security_group], options)

      raise ::DTK::Client::DtkValidationError.new("You have to provide security-group or keypair to edit target!") unless keypair || security_group

      security_groups, iaas_properties = [], {}
      iaas_properties.merge!(:keypair => keypair) if keypair

      if security_group
        raise ::DTK::Client::DtkValidationError.new("Multiple security groups should be separated with ',' and without spaces between them (e.g. --security_groups gr1,gr2,gr3,...) ") if security_group.end_with?(',')
        security_groups = security_group.split(',')
        if (security_groups.empty? || security_groups.size==1)
          iaas_properties.merge!(:security_group => security_group)
        else
          iaas_properties.merge!(:security_group_set => security_groups)
        end
      end
      @@invalidate_map << :target

      post_body = {
        :target_id => target_id,
        :iaas_properties => iaas_properties
      }
      return post rest_url("target/edit_target"), post_body
    end
  end
end
