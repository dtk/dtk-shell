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
  module RemotesMixin

    def remote_remove_aux(context_params)
      module_id, remote_name = context_params.retrieve_arguments([::DTK::Client::ModuleMixin::REQ_MODULE_ID,:option_1!], method_argument_names)
      module_type = get_module_type(context_params)

      unless options.force
        return unless Console.confirmation_prompt("Are you sure you want to remove '#{remote_name}'?")
      end

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :remote_name => remote_name
      }

      response = post rest_url("#{module_type}/remove_git_remote"), post_body
      return response unless response.ok?
      OsUtil.print("Successfully removed remote '#{remote_name}'", :green)
      nil
    end

    def remote_add_aux(context_params)
      module_id, remote_name, remote_url = context_params.retrieve_arguments([::DTK::Client::ModuleMixin::REQ_MODULE_ID,:option_1!,:option_2!], method_argument_names)
      module_type = get_module_type(context_params)

      post_body = {
        "#{module_type}_id".to_sym => module_id,
        :remote_name => remote_name,
        :remote_url  => remote_url
      }

      response = post rest_url("#{module_type}/add_git_remote"), post_body
      return response unless response.ok?
      OsUtil.print("Successfully added remote '#{remote_name}'", :green)
      nil
    end

    def remote_list_aux(context_params)
      module_id   = context_params.retrieve_arguments([::DTK::Client::ModuleMixin::REQ_MODULE_ID], method_argument_names)
      module_type = get_module_type(context_params)

      post_body = {
        "#{module_type}_id".to_sym => module_id
      }

      response = post rest_url("#{module_type}/info_git_remote"), post_body
      response.render_table(:remotes)
    end


  end
end
