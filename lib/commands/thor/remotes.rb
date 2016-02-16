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
  class Remotes < CommandBaseThor

    def self.valid_children()
      []
    end

    # REMOTE INTERACTION
    desc "push-remote", "Push local changes to remote git repository"
    method_option :force, :aliases => '--force', :type => :boolean, :default => false
    def push_remote(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "list-remotes", "List git remotes for given module"
    def list_remotes(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "add-remote", "Add git remote for given module"
    def add_remote(context_params)
      raise "NOT IMPLEMENTED"
    end

    desc "remove-remote", "Remove git remote for given module"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def remove_remote(context_params)
      raise "NOT IMPLEMENTED"
    end

  end
end
