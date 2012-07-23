module DTK; module Client
  class SshProcessing
    def self.update_ssh_known_hosts(server_dns,server_footprint)
      known_hosts_path = Internal.ssh_known_hosts_path
      if File.file?(known_hosts_path)
        `ssh-keygen -f #{known_hosts_path} -R #{server_dns}`
        File.open(known_hosts_path,"a"){|f|f << server_footprint}
      else
        ssh_base_dir = ssh_base_dir()
        unless File.directory?(ssh_base_dir)
          Dir.mkdir(ssh_base_dir)
        end
        File.open(known_hosts_path,"w"){|f|f << server_footprint}
      end
    end
    def default_rsa_pub_key_path()
      "#{ssh_base_dir()}/id_rsa.pub" 
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
 


