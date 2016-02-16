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
require 'rubygems'
require 'fileutils'
dtk_require_from_base('util/os_util')

module DTK
  module Client
    class Configurator

      CONFIG_FILE   = File.join(OsUtil.dtk_local_folder, "client.conf")
      CRED_FILE     = File.join(OsUtil.dtk_local_folder, ".connection")
      DIRECT_ACCESS = File.join(OsUtil.dtk_local_folder, ".add_direct_access")
      NODE_SSH_CREDENTIALS = File.join(OsUtil.dtk_local_folder, "ssh_credentials.yaml")

      FileUtils.mkdir(OsUtil.dtk_local_folder) unless File.directory?(OsUtil.dtk_local_folder)

      def self.check_config_exists
        exists = true
        if !File.exists?(CONFIG_FILE)
          puts "", "Please enter the DTK server address (example: instance.dtk.io)"
          header = File.read(File.expand_path('../lib/config/client.conf.header', File.dirname(__FILE__)))
          generate_conf_file(CONFIG_FILE, [['server_host', 'Server address']], header)
          exists = false
        end
        if !File.exists?(CRED_FILE)
          puts "", "Please enter your DTK login details"
          generate_conf_file(CRED_FILE, [['username', 'Username'], ['password', 'Password']], '')
          exists = false
        end

        exists
      end

      def self.check_git
        if OsUtil.which('git') == nil
          OsUtil.put_warning "[WARNING]", "Can't find the 'git' command in you path. Please make sure git is installed in order to use all features of DTK Client.", :yellow
        else
          OsUtil.put_warning "[WARNING]", 'Git username not set. This can cause issues while using DTK Client. To set it, run `git config --global user.name "User Name"`', :yellow if `git config --get user.name` == ""
          OsUtil.put_warning "[WARNING]", 'Git email not set. This can cause issues while using DTK Client. To set it, run `git config --global user.email "me@here.com"`', :yellow if `git config --get user.email` == ""
        end
      end

      # return true/false, .add_direct_access file location and ssk key file location
      def self.check_direct_access
        username_exists  = check_for_username_entry(client_username())
        ssh_key_path = SSHUtil.default_rsa_pub_key_path()

        {:username_exists => username_exists, :file_path => DIRECT_ACCESS, :ssh_key_path => ssh_key_path}
      end

      def self.generate_conf_file(file_path, properties, header)
        require 'highline/import'
        property_template = []

        properties.each do |p,d|
          begin
            trap("INT") {
              puts "", "Exiting..."
              abort
            }
          end
          value = ask("#{d}: ") { |q| q.echo = false if p == 'password'}
          property_template << [p,value]
        end

        File.open(file_path, 'w') do |f|
          f.puts(header)
          property_template.each do |prop|
            f.puts("#{prop[0]}=#{prop[1]}")
          end
        end
      end

      def self.regenerate_conf_file(file_path, properties, header)
        File.open(file_path, 'w') do |f|
          f.puts(header)
          properties.each do |prop|
            f.puts("#{prop[0]}=#{prop[1]}")
          end
        end
      end

      def self.create_missing_clone_dirs
        FileUtils.mkdir(OsUtil.component_clone_location) unless File.directory?(OsUtil.component_clone_location)
        FileUtils.mkdir(OsUtil.service_clone_location) unless File.directory?(OsUtil.service_clone_location)
        FileUtils.mkdir(OsUtil.test_clone_location) unless File.directory?(OsUtil.test_clone_location)
        FileUtils.mkdir(OsUtil.backups_location) unless File.directory?(OsUtil.backups_location)
      end


      def self.parse_key_value_file(file)
        # adapted from mcollective config
        ret = Hash.new
        raise DTK::Client::DtkError,"Config file (#{file}) does not exists" unless File.exists?(file)
        File.open(file).each do |line|
          # strip blank spaces, tabs etc off the end of all lines
          line.gsub!(/\s*$/, "")
          unless line =~ /^#|^$/
            if (line =~ /(.+?)\s*=\s*(.+)/)
              key = $1
              val = $2
              ret[key.to_sym] = val
            end
          end
        end
        ret
      end
      def self.add_current_user_to_direct_access()
        username = client_username()

        File.open(DIRECT_ACCESS, 'a') do |file|
          file.puts(username)
        end

        true
      end

      def self.client_username()
        parse_key_value_file(CRED_FILE)[:username]
      end

      #
      # Method will check if there is username entry in DIRECT_ACCESS file
      #
      def self.check_for_username_entry(username)
        if File.exists?(DIRECT_ACCESS)
          File.open(DIRECT_ACCESS).each do |line|
            if line.strip.eql?(username)
              return true
            end
          end
        end

        return false
      end

      def self.ask_catalog_credentials()
        are_there_creds = Console.confirmation_prompt("Do you have DTK catalog credentials", true)
        property_template = {}
        if are_there_creds
          property_template = self.enter_catalog_credentials()
        end

        property_template
      end

      def self.enter_catalog_credentials()
        property_template = {}
        # needed to preserve the order for ruby 1.8.7
        # ruby 1.8 does not preserve order of insertation
        wizard_values = { :username => 'Catalog Username', :password => 'Catalog Password' }
        [:username, :password].each do |p|
          value = ask("#{wizard_values[p]}: ") { |q| q.echo = false if p == :password }
          property_template.store(p, value)
        end
        property_template
      end
    end
  end
end
