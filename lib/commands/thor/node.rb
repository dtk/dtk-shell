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
dtk_require_from_base('task_status')
dtk_require_common_commands('thor/node')
dtk_require_common_commands('thor/set_required_attributes')
dtk_require_common_commands('thor/assembly_workspace')

module DTK::Client
  class Node < CommandBaseThor

    include AssemblyWorkspaceMixin
    include NodeMixin

    no_tasks do
      include TaskStatusMixin
      include SetRequiredParamsMixin
    end

    def self.pretty_print_cols()
      PPColumns.get(:node)
    end

    def self.valid_children()
      # [:component, :utils]
      [:utils]
    end

    def self.multi_context_children()
      [:utils]
    end

    def self.all_children()
      [:component, :attribute]
      # [:node]
    end

    # using extended_context when we want to use autocomplete from other context
    # e.g. we are in assembly/apache context and want to create-component we will use extended context to add
    # component-templates to autocomplete
    def self.extended_context()
      {
        :context => {
        },
        :command => {
          :add_component => {
            :endpoint => "component_template",
            :url => "component/list",
            :opts => {:subtype=>"template", :ignore => "test_module", :hide_assembly_cmps => "true"}
          },
          :delete_component => {
            :endpoint => "assembly",
            :url => "assembly/info_about",
            :opts => {:subtype=>"instance", :about=>"components"}
          }
        }
      }
    end

    def self.valid_child?(name_of_sub_context)
      return Node.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      assembly_id, workspace_id = context_params.retrieve_arguments([:service_id, :workspace_id])

      if (assembly_id || workspace_id)
        # if assebmly_id is present we're loading nodes filtered by assembly_id
        post_body = {
          :assembly_id => assembly_id||workspace_id,
          :subtype     => 'instance',
          :about       => 'nodes',
          :filter      => nil
        }

        response = get_cached_response(:service_node, "assembly/info_about", post_body)
      else
        # otherwise, load all nodes
        response = get_cached_response(:node, "node/list", nil)
      end

      return response
    end

    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :command_only => {
          :utils => [
            ['get-netstats',"get-netstats","# Get netstats."],
            ['get-ps',"get-ps [--filter PATTERN]","# Get ps."]
          ]
        }
      })
    end

    desc "NODE-NAME/ID info","Info about node"
    def info(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      post_body = {
        :node_id => node_id,
        :subtype => 'instance',
      }

       post rest_url("node/info"), post_body
    end

    desc "NODE-NAME/ID ssh [LINUX-LOGIN-USER] [-i PATH-TO-PEM]","SSH into node."
    method_option "--identity-file",:aliases => '-i',:type => :string, :desc => "Identity-File used for connection, if not provided default is used", :banner => "IDENTITY-FILE"
    def ssh(context_params)
      if OsUtil.is_windows?
        puts "[NOTICE] SSH functionality is currenly not supported on Windows."
        return
      end

      node_id, login_user = context_params.retrieve_arguments([:node_id!,:option_1],method_argument_names)

      if identity_file_location = options['identity-file']
        unless File.exists?(identity_file_location)
          raise DtkError, "Not able to find identity file, '#{identity_file_location}'"
        end
      elsif default_identity_file = OsUtil.dtk_identity_file_location()
        if File.exists?(default_identity_file)
          identity_file_location = default_identity_file
        end
      end

      response = get_node_info_for_ssh_login(node_id, context_params)
      return response unless response.ok?

      unless public_dns = response.data(:public_dns)
        raise DtkError, "Not able to resolve instance address, has instance been stopped?"
      end
      
      unless login_user ||= response.data(:default_login_user)
        raise DtkError, "Retry command with a specfic login user (a default login user could not be computed)"
      end

      connection_string = "#{login_user}@#{public_dns}"

      ssh_command = 
        if identity_file_location
          # provided PEM key
          "ssh -o \"StrictHostKeyChecking no\" -o \"UserKnownHostsFile /dev/null\" -i #{identity_file_location} #{connection_string}"
        elsif SSHUtil.ssh_reachable?(login_user, public_dns)
          # it has PUB key access
          "ssh -o \"StrictHostKeyChecking no\" -o \"UserKnownHostsFile /dev/null\" #{connection_string}"
        end

      unless ssh_command
        raise DtkError, "No public key access or PEM provided, please grant access or provide valid PEM key" 
      end
      
      OsUtil.print("You are entering SSH terminal (#{connection_string}) ...", :yellow)
      Kernel.system(ssh_command)
      OsUtil.print("You are leaving SSH terminal, and returning to DTK Shell ...", :yellow)
    end

    desc "NODE-NAME/ID list-components","List components that are on the node instance."
    method_option :list, :type => :boolean, :default => false
    def list_components(context_params)
      context_params.method_arguments = ["components"]
      list(context_params)
    end

    desc "NODE-NAME/ID list-attributes","List attributes that are on the node instance."
    method_option :list, :type => :boolean, :default => false
    def list_attributes(context_params)
      context_params.method_arguments = ["attributes"]
      list(context_params)
    end

    desc "list","List components that are on the node instance."
    method_option :list, :type => :boolean, :default => false
    def list(context_params)
      node_id, about = context_params.retrieve_arguments([:node_id,:option_1],method_argument_names)

      if node_id.nil?
        response = post rest_url("node/list")

        response.render_table(:node) unless options.list?
        return response
      else

        post_body = {
          :node_id => node_id,
          :subtype => 'instance',
          :about   => about
        }

        case about
          when "components"
            data_type = :component
          when "attributes"
            data_type = :attribute
          else
            raise_validation_error_method_usage('list')
        end

        response = post rest_url("node/info_about"), post_body
        return response.render_table(data_type)
      end
    end

    desc "NODE-NAME/ID set ATTRIBUTE-ID VALUE", "Set node group attribute value"
    def set(context_params)
      node_id, attr_id, value = context_params.retrieve_arguments([:node_id!, :option_1!, :option_2!],method_argument_names)
      post_body = {
        :node_id => node_id,
        :pattern => attr_id,
        :value => value
      }
      post rest_url("node/set_attributes"), post_body
    end

    desc "NODE-NAME/ID set-required-attributes", "Interactive dialog to set required attributes that are not currently set"
    def set_required_attributes(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      set_required_attributes_aux(node_id,:node)
    end

    # desc "NODE-NAME/ID create-component COMPONENT-TEMPLATE-NAME/ID [-v VERSION]", "Add component template to node"
    # version_method_option
    desc "NODE-NAME/ID add-component COMPONENT-TEMPLATE-NAME/ID", "Add component template to node"
    def add_component(context_params)
      node_id,component_template_id = context_params.retrieve_arguments([:node_id!, :option_1!],method_argument_names)
      post_body = {
        :node_id => node_id,
        :component_template_name => component_template_id
      }
      post_body.merge!(:version => options[:version]) if options[:version]

      response = post rest_url("node/add_component"), post_body
      return response unless response.ok?

      @@invalidate_map << :node
      return response
    end

    desc "NODE-NAME/ID delete-component COMPONENT-ID [-y]", "Delete component from node"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_component(context_params)
      node_id,component_id = context_params.retrieve_arguments([:node_id!, :option_1!],method_argument_names)

      unless options.force?
        return unless Console.confirmation_prompt("Are you sure you want to delete component '#{component_id}'"+'?')
      end

      post_body = {
        :node_id => node_id,
        :component_id => component_id
      }
      post rest_url("node/delete_component"), post_body
    end

    desc "NODE-NAME/ID converge [-m COMMIT-MSG]", "Converges service instance"
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string,
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def converge(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      # create task
      post_body = {
        :node_id => node_id
      }

      response = post rest_url("node/find_violations"), post_body
      return response unless response.ok?
      if response.data and response.data.size > 0
        #TODO: may not directly print here; isntead use a lower level fn
        error_message = "The following violations were found; they must be corrected before the node can be converged"
        OsUtil.print(error_message, :red)
        return response.render_table(:violation)
      end

      post_body.merge!(:commit_msg => options.commit_msg) if options.commit_msg

      response = post rest_url("node/create_task"), post_body
      return response unless response.ok?

      # execute task
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "NODE-NAME/ID task-status [--wait]", "Task status of running or last service task"
    method_option :wait, :type => :boolean, :default => false
    def task_status(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      task_status_aux(node_id,:node,:wait => options.wait?)
    end

    desc "NODE-NAME/ID list-task-info", "Task status details of running or last service task"
    def list_task_info(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      list_task_info_aux("node", node_id)
    end

    desc "NODE-NAME/ID cancel-task TASK_ID", "Cancels task."
    def cancel_task(context_params)
      task_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      cancel_task_aux(task_id)
    end

    # desc "list-smoketests ASSEMBLY-ID","List smoketests on asssembly"
    desc "destroy NODE-ID", "Delete and destroy (terminate) node"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def destroy(context_params)
      node_id = context_params.retrieve_arguments([:option_1!],method_argument_names)
      post_body = {
        :node_id => node_id
      }
      unless options.force?
        # Ask user if really want to delete and destroy, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to destroy and delete node '#{node_id}'"+"?")
      end

      response = post rest_url("node/destroy_and_delete"), post_body
      @@invalidate_map << :node

      return response
    end

    desc "NODE-NAME/ID op-status", "Get node operational status"
    def op_status(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      post rest_url("node/get_op_status"), :node_id => node_id
    end

    desc "NODE-NAME/ID start", "Start node instance."
    def start(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      #TODO: Rich: took this out; think it is a bug
      #assembly_id,node_id = get_assembly_and_node_id(context_params)

      node_start(node_id)
    end

    desc "NODE-NAME/ID stop", "Stop node instance."
    def stop(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)
      # Retrieving assembly_id to stop a node.. TODO create server side method that takes only node id
      #TODO: Rich: took this out; think it is a bug
      #assembly_id, node_id = get_assembly_and_node_id(context_params)

      node_stop(node_id)
    end

    desc "HIDE_FROM_BASE get-netstats", "Get netstats"
    def get_netstats(context_params)
      node_id = context_params.retrieve_arguments([:node_id!],method_argument_names)

      post_body = {
        :node_id => node_id
      }

      response = post(rest_url("node/initiate_get_netstats"), post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => false
        }
        response = post(rest_url("node/get_action_results"),post_body)
        count += 1
        if count > GETNETSTATSTRIES or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == GETNETSTATSTRIES
            ret_only_if_complete = false
          end
          sleep GETNETSTATSSLEEP
        end
      end

      #TODO: needed better way to render what is one of teh feileds which is any array (:results in this case)
      response.set_data(*response.data(:results))
      response.render_table(:netstat_data)
    end

    GETNETSTATSTRIES = 6
    GETNETSTATSSLEEP = 0.5

    desc "HIDE_FROM_BASE get-ps [FILTER]", "Get ps"
    def get_ps(context_params)
      node_id, filter_pattern = context_params.retrieve_arguments([:node_id!, :option_1],method_argument_names)

      post_body = {
        :node_id => node_id
      }

      response = post(rest_url("node/initiate_get_ps"), post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => true
        }
        response = post(rest_url("node/get_action_results"),post_body)
        count += 1
        if count > GETPSTRIES or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == GETPSTRIES
            ret_only_if_complete = false
          end
          sleep GETPSSLEEP
        end
      end

      response_processed = response.data['results'].values.flatten
      response_processed.reject! {|r| !r.to_s.include?(filter_pattern)} unless filter_pattern.nil?

      #TODO: needed better way to render what is one of teh feileds which is any array (:results in this case)
      response.set_data(*response_processed)
      response.render_table(:ps_data)
    end
    GETPSTRIES = 6
    GETPSSLEEP = 0.5

    no_tasks do
      def node_start(node_id)
        post_body = {
          :node_id  => node_id
        }

        # we expect action result ID
        response = post rest_url("node/start"), post_body
        return response  if response.data(:errors)

        action_result_id = response.data(:action_results_id)

        # bigger number here due to possibilty of multiple nodes
        # taking too much time to be ready
        18.times do
          action_body = {
            :action_results_id  => action_result_id,
            :using_simple_queue => true
          }
          response = post(rest_url("assembly/get_action_results"),action_body)

          if response['errors']
            return response
          end

          break unless response.data(:result).nil?

          puts "Waiting for nodes to be ready ..."
          sleep(10)
        end

        if response.data(:result).nil?
          raise DtkError, "Server seems to be taking too long to start node(s)."
        end

        task_id = response.data(:result)['task_id']
        post(rest_url("task/execute"), "task_id" => task_id)
      end

      def node_stop(node_id)
        post_body = {
          :node_id => node_id
        }

        post rest_url("node/stop"), post_body
      end
      # get numeric ID, from possible name id
      def get_assembly_and_node_id(context_params)
        response = info(context_params)
        unless response.ok?
          raise DtkError, "Unable to retrive node information, please try again."
        end

        return response.data(:assembly_id), response.data(:id)
      end
    end
  end
end
