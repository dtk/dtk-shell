require 'base64'

module DTK::Client
  class Developer < CommandBaseThor

    MATCH_FILE_NAME  = /[a-zA-Z0-9_]+\.[a-zA-Z]+$/
    GIT_LOG_LOCATION = File.expand_path('../../../lib/git-logs/git.log', File.dirname(__FILE__))
    PROJECT_ROOT     = File.expand_path('../../../', File.dirname(__FILE__))

    desc "upload-agent PATH-TO-AGENT[.rb,.dll] NODE-ID-PATTERN", "Uploads agent and ddl file to requested nodes, pattern is regexp for filtering node ids." 
    def upload_agent(context_params)
      agent, node_pattern = context_params.retrieve_arguments([:option_1!, :option_2!],method_argument_names)

      nodes = post rest_url("node/list"), { :is_list_all => true }

      ids = []
      # get all nodes which id starts with node_pattern
      nodes["data"].collect{|a| ids<<a["id"].to_i if a["id"].to_s.match(Regexp.new(node_pattern.to_s)) }
      raise DTK::Client::DtkValidationError, "Unable to find nodes to match this pattern: '#{node_pattern}'." if ids.empty?

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
    	response = post_file rest_url("developer/inject_agent"), { :agent_files => request_body, :node_pattern => node_pattern, :node_list => ids }
      puts "Agent uploaded successfully!";return if response.ok?
      return response
    end

    desc "remove-from-system SERVICE-NAME", "Removes objects associated with service, but does not destroy target isnatnces"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def remove_from_system(context_params)
      assembly_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      unless options.force?
        # Ask user if really want to delete assembly, if not then return to dtk-shell without deleting
        what = "service"
        return unless Console.confirmation_prompt("Are you sure you want to remove #{what} '#{assembly_id}' and its nodes from the system"+'?')
      end

      response = post rest_url("assembly/remove_from_system"), {:assembly_id => assembly_id}
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :service
      return response
    end

    desc "apply-param-set SERVICE-NAME/ID PARAM-SET-PATH", "Uses the parametrs set in the file PARAM-SET-PATH and appleis to the service"
    def apply_param_set(context_params)
      assembly_id,path = context_params.retrieve_arguments([:option_1!,:option_2!],method_argument_names)
      av_pairs = JSON.parse(File.open(path).read)

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
      Response::Ok.new()
    end

    desc "commits", "View last commits that went into the gem"
    def commits(context_params)
      unless File.file?(GIT_LOG_LOCATION)
        raise DTK::Client::DtkError, "Git log file not found, contact DTK support team."
      end

      File.readlines(GIT_LOG_LOCATION).reverse.each do |line|
        puts line
      end
    end

    desc "content FILE-NAME", "Get content of file name in DTK Client gem"
    def content(context_params)
      file_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      found_files = Dir["#{PROJECT_ROOT}/**/*.*"].select { |fname| fname.end_with?(file_name) }

      if found_files.empty?
        raise DTK::Client::DtkValidationError, "No files found with name '#{file_name}'."
      else
        found_files.each do |fname|
          header = "*********************** #{fname} ***********************"
          DTK::Client::OsUtil.print(header, :yellow)
          puts File.open(fname).readlines
          DTK::Client::OsUtil.print("*"*header.size, :yellow)
        end
      end  

    end
  end
end
