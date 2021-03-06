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
module DTK; module Client; class CommandHelper
  class GitRepo
    class Merge

      def initialize(repo, remote_branch_ref, opts = {})
        @repo              = repo
        @remote_branch_ref = remote_branch_ref
        @local_branch      = repo.local_branch_name
        
        # options
        @opts_commit_sha = opts[:commit_sha]
        @opts_force = opts[:force]
        @opts_ignore_dependency_merge_conflict = opts[:ignore_dependency_merge_conflict]
        @opts_full_module_name = opts[:full_module_name]
        @opts_command = opts[:command]
      end
      
      def self.merge(repo, remote_branch_ref, opts = {})
        new(repo, remote_branch_ref, opts).merge
      end

      def merge
        if @opts_force
          merge_force()
        else
          # check if merge needed
          merge_rel = merge_relationship()
          case merge_rel
           when :equal 
            response__no_diffs()
           when :local_ahead, :branchpoint
            merge_not_fast_forward(merge_rel)
           when :local_behind
            merge_simple()
           else
            raise Error.new("Unexpected merge_rel (#{merge_rel})")
          end
        end
      end

      private
      
      def merge_force
        diffs = compute_diffs()
        # TODO: should put in a commit message that merged from remote repo
        @repo.merge_theirs(@remote_branch_ref)
        response(diffs)
      end
      
      def merge_not_fast_forward(merge_rel)
        if any_conflicts?
          # @opts_ignore_dependency_merge_conflict means called indirectly
          if @opts_ignore_dependency_merge_conflict
            # TODO: hard-wired that dependency is a component module in message: 'component-module/..
            custom_message = "Unable to do fast-forward merge. You can go to 'component-module/#{@opts_full_module_name}' and pull with --force option but all local changes will be lost." 
            response(compute_diffs, :custom_message => custom_message)
          else
            err_msg = 'Unable to do fast-forward merge. You can use --force'
            err_msg << " on #{@opts_command}" if @opts_command
            err_msg <<  ', but all local changes will be lost on target that is being pushed to.'
            raise ErrorUsage.new(err_msg)
          end
        elsif  merge_rel == :local_ahead
          response__no_diffs(:custom_message => 'No op because local module is ahead')
        else
          merge_simple()
        end
      end

      def merge_simple
        # see if any diffs between fetched remote and local branch
        # this has be done after commit
        diffs = compute_diffs()
        return diffs unless diffs.any_diffs?()
        
        safe_execute do
          # TODO: should put in a commit message that merged from remote repo
          @repo.merge(@remote_branch_ref)
        end
        
        if commit_sha = @opts_commit_sha
          if commit_sha != @repo.head_commit_sha()
            raise Error.new("Git synchronization problem: expected local head to have sha (#{commit_sha})")
          end
        end
        
        response(diffs)
      end
      
      def merge_relationship
        @repo.merge_relationship(:remote_branch, @remote_branch_ref)    
      end
      
      def any_conflicts?
        # TODO: optimization is to combine this with mereg to have merge_if_no_conflics? 
        #       and if no conflicts just commit and merge --no-commit
        ret = nil
        begin
          @repo.command('merge',['--no-commit', @remote_branch_ref])
         rescue ::Git::GitExecuteError
          ret = true
        ensure
          safe_execute do
            @repo.command('merge',['--abort'])
          end
        end
        ret
      end

      def response__no_diffs(opts_response = {})
        response(diffs__no_diffs(), opts_response)
      end

      def response(diffs, opts_response = {})
        { :diffs => diffs, :commit_sha => @repo.head_commit_sha() }.merge(opts_response)
      end
      
      def diffs__no_diffs
        GitRepo.diffs__no_diffs
      end
      
      def compute_diffs
        GitRepo.compute_diffs(@repo,  @remote_branch_ref)
      end
      
      def safe_execute(&block)
        begin
          yield
         rescue Exception
          nil
        end
      end

    end
  end
end; end; end
