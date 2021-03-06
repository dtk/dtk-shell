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
# TODO: Marked for removal [Haris] - Do we need this?
require 'jenkins-client'
module DTK; module Client
  class JenkinsClient
    require File.expand_path('jenkins_client/config_xml', File.dirname(__FILE__))

    def self.create_service_module_project(module_id,module_name,repo_url,branch)
      jenkins_project_name = module_name
      config_xml_contents = ConfigXML.generate_service_module_project(repo_url,module_id,branch)
      connection().create_job(jenkins_project_name,config_xml_contents)
    end

    def self.create_service_module_project?(module_id,module_name,repo_url,branch)
      jenkins_project_name = module_name
      jobs = get_jobs()||[]
      #no op if job exists already
      unless jobs.find{|j|j["name"] == jenkins_project_name}
        create_service_module_project(module_id,module_name,repo_url,branch)
      end
    end

    def self.create_assembly_project(assembly_name,assembly_id)
      jenkins_project_name = assembly_name.gsub(/::/,"-")
      config_xml_contents = ConfigXML.generate_assembly_project(assembly_id)
      connection().create_job(jenkins_project_name,config_xml_contents)
    end

    def self.create_assembly_project?(assembly_name,assembly_id)
      jenkins_project_name = assembly_name.gsub(/::/,"-")
      jobs = get_jobs()||[]
      #no op if job exists already
      unless jobs.find{|j|j["name"] == jenkins_project_name}
        create_assembly_project(assembly_name,assembly_id)
      end
    end

    def self.get_jobs()
      connection().get_jobs()
    end

   private
    def self.connection()
      return @connection if @connection
      #TODO: hardwired
      connection_hash = {
        :username => "rich",
        :password => "test",
        :url => "http://ec2-107-22-254-226.compute-1.amazonaws.com:8080"
      }
      @connection = Connection.new(connection_hash)
    end

    class Connection < Hash
      def initialize(connection_hash)
        super()
        merge!(connection_hash)
        set_connection()
      end
      def create_job(job_name,config_xml_contents)
        ::Jenkins::Client::Job.create(job_name, config_xml_contents)
      end

      def get_info()
        get('api/json')
      end

      def get_jobs()
        get_info()["jobs"]
      end
     private
      #TODO: one issue with the jenkins-client adapter is that it a singleton and thus only allows connection under one user to one jenkins server
      def set_connection()
        ::Jenkins::Client.configure do |c|
          c.username = self[:username]
          c.password = self[:password]
          c.url = self[:url]
        end
      end

      def get(path)
        faraday_response = ::Jenkins::Client.get(path)
        unless [200].include?(faraday_response.status)
          raise Error.new("Bad response from Jenkins (status = #{faraday_response.status.to_s})")
        end
        faraday_response.body
      end
    end
  end
end; end
