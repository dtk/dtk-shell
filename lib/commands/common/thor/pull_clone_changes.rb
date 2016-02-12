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
dtk_require_common_commands('thor/common')
module DTK::Client
  module PullCloneChangesMixin
    def pull_clone_changes?(module_type,module_id,version=nil,opts={})
      module_name, module_namespace,repo_url,branch,not_ok_response = workspace_branch_info(module_type,module_id,version,opts)
      return not_ok_response if not_ok_response
      opts_pull = opts.merge(:local_branch => branch,:namespace => module_namespace)
      Helper(:git_repo).pull_changes(module_type,module_name,opts_pull)
    end
  end
end