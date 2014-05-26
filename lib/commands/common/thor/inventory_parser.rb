dtk_require_from_base('configurator')
module DTK::Client
  module InventoryParserMixin
   private

    def parse_inventory_file(file_path)
      ssh_creds_path = ::DTK::Client::Configurator::NODE_SSH_CREDENTIALS
      ssh_creds_data = parse_ssh_credentials_file(ssh_creds_path)

      hash = validate_inventory_data(file_path)

      ret = Hash.new
      defaults = hash["defaults"]

      hash["nodes"].each do |node_name, data|
        display_name = data["name"]||node_name
        ssh_credentials = data["ssh_credentials"]||defaults["ssh_credentials"]

        raise DtkValidationError, "Credentials for '#{ssh_credentials}' does not exist in credentials file '#{ssh_creds_path}'" unless ssh_creds_data.include?(ssh_credentials)
        
        ref = "physical--#{display_name}"
        ret[ref] = {
          :display_name => display_name,
          :os_type => data["os_type"]||defaults["os_type"],
          :managed => false,
          :external_ref => {:type => "physical", :routable_host_address => node_name, :ssh_credentials => ssh_creds_data["#{ssh_credentials}"]}
        }
      end

      ret
    end

    def parse_ssh_credentials_file(file_path)
      begin
        data = YAML.load_file(file_path)
      rescue SyntaxError => e
        raise DSLParsing::YAMLParsing.new("YAML parsing error #{e.message} in file", file_path)
      end

      data.each do |k,v|
        raise DtkValidationError, "File: '#{file_path}'. Ssh credentials '#{k}' missing required field 'ssh_user'." unless v['ssh_user']
        raise DtkValidationError, "File: '#{file_path}'. Ssh credentials '#{k}' should contain 'ssh_password' or 'sudo_password'." unless (v['ssh_password'] || v['sudo_password'])
      end

      data
    end

    def validate_inventory_data(file_path)
      begin
        data = YAML.load_file(file_path)
      rescue SyntaxError => e
        raise DSLParsing::YAMLParsing.new("YAML parsing error #{e.message} in file", file_path)
      end

      defaults = data['defaults']||[]
      nodes = data['nodes']||[]

      nodes.each do |k,v|
        os_type = v['os_type']||defaults['os_type']
        ssh_credentials = v['ssh_credentials']||defaults['ssh_credentials']

        # os_type is required field and should be set through node specific fields or used from defaults
        raise DtkValidationError, "Missing required field 'os_type' for node '#{k}'." unless os_type

        # ssh_credentials is required field and should be set through node specific fields or used from defaults
        raise DtkValidationError, "Missing required field 'ssh_credentials' for node '#{k}'." unless ssh_credentials

        # currently we support 'ubuntu', 'centos, 'redhat' and 'debian' as os types and should be set through node specific field
        # or used from defaults
        raise DtkValidationError, "Os_type '#{os_type}' is not valid for node '#{k}'. Valid os types: #{ValidOsTypes}." unless ValidOsTypes.include?(os_type)
      end

      data
    end
    ValidOsTypes = ['ubuntu', 'centos', 'redhat', 'debian']

  end
end
