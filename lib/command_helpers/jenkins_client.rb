require 'jenkins-client' 
module DTK; module Client
  class JenkinsClient
    require File.expand_path('jenkins_client/config_xml', File.dirname(__FILE__))

    def self.createJenkins_project(module_id,module_name,repo_url,branch)
      #TODO: should probably make this no op if project exists already and using Ruby convention renamemethod to createJenkins_project?
      jenkins_project_name = module_name
      config_xml_contents = ConfigXML.generate(repo_url,module_id,branch)
      connection().create_job(jenkins_project_name,config_xml_contents)
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
     private
      #TODO: one issue with the jenkins-client adapter is that it a singleton and thus only allows connection under one user to one jenkins server
      def set_connection()
        ::Jenkins::Client.configure do |c|
          c.username = self[:username]
          c.password = self[:password]
          c.url = self[:url]
        end
      end
    end
  end
end; end
 


