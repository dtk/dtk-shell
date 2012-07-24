require 'jenkins-client' 
module DTK; module Client
  class JenkinsClient
    require File.expand_path('jenkins_client/config_xml', File.dirname(__FILE__))

    def self.createJenkins_project(module_id,module_name,repo_url,branch)
      #TODO: should probably make this no op if project exists already and using Ruby convention renamemethod to createJenkins_project?

      jenkins_username = "rich" #TODO: stubbed: must be replaced
      jenkins_password = "test" #TODO: stubbed: must be replaced
      jenkins_server_url = "http://ec2-50-19-5-150.compute-1.amazonaws.com:8080" #TODO: stubbed: must be replaced
      set_connection(jenkins_username,jenkins_password,jenkins_server_url)

      jenkins_project_name = module_name
      config_xml_contents = ConfigXML.generate(repo_url,module_id,branch)
      create_job(jenkins_project_name,config_xml_contents)
    end

   private
    #wrapped adapters
    #TODO: one issue with the jenkins-client adapter is that it a singleton and thus only allows connection under one user to one jenkins server
    def self.set_connection(username,password,jenkins_server_url)
      Jenkins::Client.configure do |c|
        c.username = username
        c.password = password
        c.url = jenkins_server_url
      end
    end
    def self.create_job(job_name,config_xml_contents)
      Jenkins::Client::Job.create(job_name, config_xml_contents)
    end
  end
end; end
 


