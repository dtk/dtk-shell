dtk_require_from_base('configurator')
module DTK::Client
  module InventoryParserMixin
   private

    def parse_inventory_file(file_path)
      hash = YAML.load_file(file_path)
      ssh_creds_path = ::DTK::Client::Configurator::NODE_SSH_CREDENTIALS
      ssh_creds_data = YAML.load_file(ssh_creds_path)

      ret = Hash.new
      defaults = hash["defaults"]

      hash["nodes"].each do |node_name, data|
        display_name = data["name"]||node_name
        ssh_credentials = data["ssh_credentials"]||defaults["ssh_credentials"]

        raise DTK::Client::DtkValidationError, "Credentials for '#{ssh_credentials}' does not exist in credentials file '#{ssh_creds_path}'" unless ssh_creds_data.include?(ssh_credentials)
        
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

  end
end
