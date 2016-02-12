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
  class NodeTemplate < CommandBaseThor

    def self.pretty_print_cols()
      PPColumns.get(:node)
    end

    def self.extended_context()
      {
        :context => {
          :add_component => "component_template"
        }
      }
    end

    def self.validation_list(context_params)
      get_cached_response(:node_template, "node/list", {:subtype => 'template'})
    end

#    desc "list --all -t [TARGET-NAME]", "List all node templates."
    desc "list", "List all node templates."
    method_option :all, :type => :boolean, :default => false
    method_option "target_identifier",:aliases => "-t" ,
      :type => :string,
      :banner => "TARGET-IDENTIFIER",
      :desc => "Name or ID of desired target"
    def list(context_params)
      post_body = {
        :subtype => 'template',
        :target_indentifier => options.target_identifier,
        :is_list_all => options.all
      }
      response = post rest_url("node/list"), post_body
      response.render_table(options.all ? :node_template_all : :node_template)
    end

    #TODO: this may be moved to just be a utility fn
    desc "image-upgrade OLD-IMAGE-ID NEW-IMAGE-ID", "Upgrade use of OLD-IMAGE-ID to NEW-IMAGE-ID"
    def image_upgrade(context_params)
      old_image_id, new_image_id = context_params.retrieve_arguments([:option_1!, :option_2!],method_argument_names)
      post_body = {
        :old_image_id => old_image_id,
        :new_image_id => new_image_id
      }
      post rest_url("node/image_upgrade"), post_body
    end

    desc "add-node-template NODE-TEMPLATE-NAME [-t TARGET-NAME/ID] --os OS --image-id IMAGE-ID --size SIZE[,SIZE2,..]", "Add new node template"
    method_option "target",:aliases => "-t"
    method_option "os"
    method_option "image-id",:aliases => "-i"
    method_option "size",:aliases => "-s"
    def add_node_template(context_params)
      node_template_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      size_array = options[:size] && options[:size].split(',')

      post_body = post_body(
        :node_template_name => node_template_name,
        :target_id => options['target'],
        :operating_system => required_option('os'),
        :image_id => required_option('image-id'),
        :size_array => size_array
      )
      post rest_url("node/add_node_template"), post_body
    end

    desc "delete-node-template NODE-TEMPLATE-NAME", "Delete node template"
    def delete_node_template(context_params)
      node_template_name = context_params.retrieve_arguments([:option_1!],method_argument_names)
      post_body = post_body(
        :node_template_name => node_template_name
      )
      post rest_url("node/delete_node_template"), post_body
    end

  end
end