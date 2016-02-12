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
module DTK
  module Client
    module SSHUtil

      def self.read_and_validate_pub_key(path_to_pub_key)
        is_ssh_key_path_valid?(path_to_pub_key)
        rsa_pub_key = File.open(path_to_pub_key) { |f| f.read }
        is_ssh_key_content_valid?(rsa_pub_key)
        rsa_pub_key
      end

      def self.update_ssh_known_hosts(server_dns,server_fingerprint)
        known_hosts_path = ssh_known_hosts_path()
        if File.file?(known_hosts_path)
          `ssh-keygen -f #{known_hosts_path} -R #{server_dns} 2> /dev/null`
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

      def self.ssh_reachable?(user, server, timeout = 3)
        output = `ssh -o ConnectTimeout=#{timeout} -o \"StrictHostKeyChecking no\" -o \"UserKnownHostsFile /dev/null\" -q #{user}@#{server} exit; echo $?`

        # if response 0 than it is able to connect
        "0".eql?(output.strip())
      end


    private

      def self.ssh_base_dir()
        "#{OsUtil.dtk_home_dir}/.ssh"
      end
      
      def self.ssh_known_hosts_path()
        "#{ssh_base_dir()}/known_hosts"
      end

      def self.is_ssh_key_path_valid?(path_to_key)
        unless path_to_key.include?(".pub")
          raise DtkError, "[ERROR] Invalid public key file path (#{path_to_key}). Please provide valid path and try again."
        end

        unless File.exists?(path_to_key)
          raise DtkError, "[ERROR] Not able to find provided key (#{path_to_key}). Please provide valid path and try again."
        end
      end

      def self.is_ssh_key_content_valid?(rsa_pub_key)
        # checking know ssh rsa pub key content
        if(rsa_pub_key.empty? || !rsa_pub_key.include?("AAAAB3NzaC1yc2EA"))
          raise DtkError, "[ERROR] SSH public key (#{path_to_key}) does not have valid content. Please check your key and try again."
        end
      end

    end
  end
end