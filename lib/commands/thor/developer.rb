require 'base64'

module DTK::Client
  class Developer < CommandBaseThor

    MATCH_FILE_NAME = /[a-zA-Z0-9]+\.[a-zA-Z]+$/

    desc "upload_agent PATH-TO-AGENT[.rb,.dll] NODE-ID-PATTERN", "Uploads agent and ddl file to requested nodes, pattern is regexp for filtering node ids." 
    def upload_agent(context_params)
      agent, node_pattern = context_params.retrieve_arguments([:option_1!, :option_2!],method_argument_names)
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

    desc "remove-from-system ASSEMBLY-NAME", "Removes objects associated with assembly, but does not destroy target isnatnces"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def remove_from_system(context_params)
      assembly_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      unless options.force?
        # Ask user if really want to delete assembly, if not then return to dtk-shell without deleting
        what = "assembly"
        return unless Console.confirmation_prompt("Are you sure you want to remove #{what} '#{assembly_id}' and its nodes from the system"+'?')
      end

      response = post rest_url("assembly/remove_from_system"), {:assembly_id => assembly_id}
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly
      return response
    end

    desc "apply-param-set ASSEMBLY-NAME/ID PARAM-SET-PATH", "Uses the parametrs set in the file PARAM-SET-PATH and appleis to teh assembly"
    def apply_param_set(context_params)
      assembly_id,path = context_params.retrieve_arguments([:option_1!,:option_2!],method_argument_names)
      repsonse = nil
      av_pairs = JSON.parse(File.open("/tmp/params.json").read)

      av_pairs.each do |a,v|
        post_body = {
          :assembly_id => assembly_id,
          :pattern => a,
          :value => v
        }
        response = post rest_url("assembly/set_attributes"), post_body
        if response.ok?
          pp response.data
        else
          return response
        end
      end
      response #TODO: shoudl return just ok not last response
    end

  end
end
