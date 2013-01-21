require 'base64'

module DTK::Client
  class Developer < CommandBaseThor

    MATCH_FILE_NAME = /[a-zA-Z0-9]+\.[a-zA-Z]+$/

    desc "upload_agent PATH-TO-AGENT[.rb,.dll] NODE-ID-PATTERN", "Uploads agent and ddl file to requested nodes, pattern is regexp for filtering node ids." 
    def upload_agent(hashed_args)
      agent, node_pattern = CommandBaseThor.retrieve_arguments([:option_1, :option_2],hashed_args)
      # if it doesn't contain extension upload both *.rb and *.ddl
      files = (agent.match(MATCH_FILE_NAME) ? [agent] : ["#{agent}.rb","#{agent}.ddl"])
    
    	# read require files and encode them
      request_body = {}
    	files.each do |file_name|
    		raise DTK::Client::DtkError, "Unable to load file: #{file_name}" unless File.exists?(file_name)
        # reason for this to file dues to previus match
        agent_name = file_name.match(MATCH_FILE_NAME)[0]
    		File.open(file_name) { |file| request_body.store(agent_name,Base64.encode64(file.read)) }
    	end

      # send as binary post request
    	response = post_file rest_url("developer/inject_agent"), { :agent_files => request_body, :node_pattern => node_pattern }
      return response
    end

  end
 end