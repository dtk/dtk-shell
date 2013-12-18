module DTK; module Client
  class SshProcessing
    def self.update_ssh_known_hosts(server_dns,server_fingerprint)
      known_hosts_path = ssh_known_hosts_path()
      if File.file?(known_hosts_path)
        `ssh-keygen -f #{known_hosts_path} -R #{server_dns}`
        File.open(known_hosts_path,"a"){|f|f << server_fingerprint}
      else
        ssh_base_dir = ssh_base_dir()
        unless File.directory?(ssh_base_dir)
          Dir.mkdir(ssh_base_dir)
        end
        File.open(known_hosts_path,"w"){|f|f << server_fingerprint}
      end
    end
    def self.default_rsa_pub_key_path()
      "#{ssh_base_dir()}/id_rsa.pub" 
    end

    def self.rsa_pub_key_content()
      path_to_key = self.default_rsa_pub_key_path()
      unless File.file?(path_to_key)
        raise DtkError,"No File found at (#{path_to_key}). Path is wrong or it is necessary to generate the public rsa key (e.g., run ssh-keygen -t rsa)"
      end

      content = File.open(path_to_key){ |f| f.read }
      content.chomp
    end


   private
    def self.ssh_base_dir()
      "#{ENV['HOME']}/.ssh" #TODO: very brittle
    end
    
    def self.ssh_known_hosts_path()
      "#{ssh_base_dir()}/known_hosts"
    end
  end
end; end
 


