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

      module_name = response.data(:full_module_name)

      opts = {
        :remote_repo_url => response.data(:remote_repo_url),
        :remote_repo => response.data(:remote_repo),
        :remote_branch => response.data(:remote_branch),
        :local_branch => response.data(:workspace_branch)
      }
      version = response.data(:version)

      # response = Helper(:git_repo).get_diffs(module_type,module_name,version,opts)
      response = Helper(:git_repo).get_remote_diffs(module_type,module_name,version,opts)
      return response unless response.ok?

      added, deleted, modified = print_diffs(response.data(:status), remote)
      diffs = response.data(:diffs)

      raise DTK::Client::DtkValidationError, "There are no changes in current workspace!" if(added.empty? && deleted.empty? && modified.empty? && diffs.empty?)
      puts "#{diffs}" unless (diffs||"").empty?

      unless added.empty?
        puts "\nNew file(s):"
        added.each do |a|
          puts "\t #{a.inspect}"
        end
      end

      unless deleted.empty?
        puts "\nDeleted file(s):"
        deleted.each do |d|
          puts "\t #{d.inspect}"
        end
      end
  	end

    def list_remote_diffs_aux(module_type, module_id)
      id_field = "#{module_type}_id"

      post_body = {
        id_field => module_id
      }

      response = post(rest_url("#{module_type}/list_remote_diffs"),post_body)
      return response unless response.ok?

      raise DTK::Client::DtkValidationError, "There are no diffs between module on server and remote repo!" if response.data.empty?
      response
    end

    def list_component_module_diffs(module_id, assembly_name, workspace_branch, commit_sha, module_branch_id, repo_id)
      post_body = {
        :module_id => module_id,
        :assembly_name => assembly_name,
        :workspace_branch => workspace_branch,
        :module_branch_id => module_branch_id,
        :repo_id => repo_id
      }

      response = post(rest_url("assembly/list_component_module_diffs"),post_body)
      return response unless response.ok?

      raise DTK::Client::DtkValidationError, "There are no diffs between module in service instance and base module!" if response.data.empty?
      response
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
