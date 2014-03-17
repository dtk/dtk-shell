module DTK::Client
  module ListDiffsMixin
  	def list_diffs_aux(module_type,module_id,remote,version=nil)
  		id_field    = "#{module_type}_id"
      path_to_key = SSHUtil.default_rsa_pub_key_path()
      rsa_pub_key = File.file?(path_to_key) && File.open(path_to_key){|f|f.read}.chomp

      post_body = {
        id_field => module_id,
        :access_rights => "r",
        :action => "pull"
      }
      post_body.merge!(:version => version) if version
      post_body.merge!(:rsa_pub_key => rsa_pub_key) if rsa_pub_key

      response = post(rest_url("#{module_type}/get_remote_module_info"),post_body)
      return response unless response.ok?
      
      module_name = response.data(:module_name)
      opts = {
        :remote_repo_url => response.data(:remote_repo_url),
        :remote_repo => response.data(:remote_repo),
        :remote_branch => response.data(:remote_branch),
        :local_branch => response.data(:workspace_branch)
      }
      version = response.data(:version)

      response = Helper(:git_repo).get_diffs(module_type,module_name,version,opts)
      return response unless response.ok?

      added, deleted, modified = print_diffs(response.data(remote ? :diffs : :status), remote)

      raise DTK::Client::DtkValidationError, "There is no changes in current workspace!" if(added.empty? && deleted.empty? && modified.empty?)
      
      unless added.empty?
        puts "ADDED:"
        added.each do |a|
          puts "\t #{a.inspect}"
        end
      end

      unless deleted.empty?
        puts "DELETED:"
        deleted.each do |d|
          puts "\t #{d.inspect}"
        end
      end

      unless modified.empty?
        puts "MODIFIED:"
        modified.each do |m|
          puts "\t #{m.inspect}"
        end
      end
  	end

    def print_diffs(response, remote)
      added    = []
      deleted  = []
      modified = []

      unless response[:files_modified].nil?
        response[:files_modified].each do |file|
          modified << file[:path]
        end
      end

      unless response[:files_deleted].nil?
        response[:files_deleted].each do |file|
          deleted << file[:path]
        end
      end

      unless response[:files_added].nil?
        response[:files_added].each do |file|
          added << file[:path]
        end
      end

      return added, deleted, modified
    end

  end
end