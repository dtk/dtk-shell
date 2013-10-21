require 'rest_client'
require 'json'
require 'colorize'
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_from_base("command_helper")
dtk_require_common_commands('thor/task_status')
dtk_require_common_commands('thor/set_required_params')
dtk_require_common_commands('thor/edit')
dtk_require_common_commands('thor/purge_clone')
LOG_SLEEP_TIME_W   = DTK::Configuration.get(:tail_log_frequency)

# regex: (context_params.retrieve_arguments\([a-z\[\]:_,0-9!]+)
# replace: $1,method_argument_names

module DTK::Client
  class Utils < CommandBaseThor
    no_tasks do
      include TaskStatusMixin
      include SetRequiredParamsMixin
      include EditMixin
      include PurgeCloneMixin
      def get_workspace_name(workspace_id)
        get_name_from_id_helper(workspace_id)
      end
    end

    def self.whoami()
      return :utils#, "assembly/list", {:subtype  => 'instance'}
    end

    def self.pretty_print_cols()
      PPColumns.get(:assembly)
    end

    def self.valid_children()
      [:node]
    end

    # using extended_context when we want to use autocomplete from other context
    # e.g. we are in assembly/apache context and want to add-component we will use extended context to add 
    # component-templates to autocomplete
    def self.extended_context()
      # {:add_component => "component_template", :create_node => "node_template"}
      {}
    end

    # this includes children of children
    def self.all_children()
      # [:node, :component, :attribute]
      []
    end

    def self.valid_child?(name_of_sub_context)
      return Utils.valid_children().include?(name_of_sub_context.to_sym)
    end

    def self.validation_list(context_params)
      get_cached_response(:utils, "assembly/list_with_workspace", {})
    end

    # TODO: Hack which is necessery for the specific problem (DTK-541), something to reconsider down the line
    # at this point not sure what would be clenear solution

    # :all             => include both for commands with command and identifier
    # :command_only    => only on command level
    # :identifier_only => only on identifier level for given entity (command)
    #
    def self.override_allowed_methods()
      return DTK::Shell::OverrideTasks.new({
        :all => {
          :node      => [
            # ['delete-component',"delete-component COMPONENT-ID","# Delete component from assembly's node"],
            ['list',"list [FILTER] [--list] ","# List nodes"],
            ['list-components',"list-components [FILTER] [--list] ","# List components associated with workspace's node."],
            ['list-attributes',"list-attributes [FILTER] [--list] ","# List attributes associated with workspace's node."]
          ],
          :component => [
            ['list',"list [FILTER] [--list] ","# List components."],
            ['list-attributes',"list-attributes [FILTER] [--list] ","# List attributes associated with given component."],
            ['list-service-links',"list-service-links","# List service links for component."],
            ['create-service-link',"create-service-link SERVICE-TYPE DEPENDENT-CMP-NAME/ID","# Add service link to component."],
            ['delete-service-link',"delete-service-link SERVICE-TYPE","# Delete service link on component."],
            ['create-attribute',"create-attribute SERVICE-TYPE DEP-ATTR ARROW BASE-ATTR","# Create an attribute to service link."],
            ['list-attribute-mappings',"list-attribute-mappings SERVICE-TYPE","# List attribute mappings assocaited with service link."]
          ]
        },
        :command_only => {
          :attribute => [
            ['list',"list [attributes] [FILTER] [--list] ","# List attributess."]
          ]
        },
        :identifier_only => {
          :node      => [
            # ['add-component',"add-component NODE-ID COMPONENT-TEMPLATE-NAME/ID [DEPENDENCY-ORDER-INDEX]","# Return info about node instance belonging to given workspace."],
            ['info',"info","# Return info about node instance belonging to given workspace."],
            ['get-netstats',"get-netstats","# Returns getnetstats for given node instance belonging to context workspace."],
            ['get-ps', "get-ps [--filter PATTERN]", "# Returns a list of running processes for a given node instance belonging to context workspace."]
          ],
          :component => [
            ['info',"info","# Return info about component instance belonging to given node."],
            ['edit',"edit","# Edit component module related to given component."]
          ],
          :attribute => [
            ['info',"info","# Return info about attribute instance belonging to given component."]
          ]
        }
      })
    end


    desc "get-netstats", "Get netstats"
    def get_netstats(context_params)
      netstat_tries = 6
      netstat_sleep = 0.5

      workspace_id,node_id = context_params.retrieve_arguments([:workspace_id!,:node_id],method_argument_names)

      post_body = {
        :assembly_id => workspace_id,
        :node_id => node_id
      }  

      response = post(rest_url("assembly/initiate_get_netstats"),post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => false,
          :sort_key => "port"
        }
        response = post(rest_url("assembly/get_action_results"),post_body)
        count += 1
        if count > netstat_tries or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == netstat_tries
            ret_only_if_complete = false
          end
          sleep netstat_sleep
        end
      end

      #TODO: needed better way to render what is one of teh feileds which is any array (:results in this case)
      response.set_data(*response.data(:results))
      response.render_table(:netstat_data)
    end




    desc "get-ps [--filter PATTERN]", "Get ps"
    method_option :filter, :type => :boolean, :default => false, :aliases => '-f'
    def get_ps(context_params)

      get_ps_tries = 6
      get_ps_sleep = 0.5

      workspace_id,node_id,filter_pattern = context_params.retrieve_arguments([:workspace_id!,:node_id, :option_1],method_argument_names)

      post_body = {
        :assembly_id => workspace_id,
        :node_id => node_id
      }  
      
      response = post(rest_url("assembly/initiate_get_ps"),post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => false,
          :sort_key => "pid"
        }
        response = post(rest_url("assembly/get_action_results"),post_body)
        count += 1
        if count > get_ps_tries or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == get_ps_tries
            ret_only_if_complete = false
          end
          sleep get_ps_sleep
        end
      end
      filtered = response.data(:results).flatten

      # Amar: had to add more complex filtering in order to print node id and node name in output, 
      #       as these two values are sent only in the first element of node's processes list
      unless (filter_pattern.nil? || !options["filter"])    
        node_id = ""
        node_name = ""    
        filtered.reject! do |r|
          match = r.to_s.include?(filter_pattern)
          if r["node_id"] && r["node_id"] != node_id
            node_id = r["node_id"]
            node_name = r["node_name"]
          end
             
          if match && !node_id.empty?
            r["node_id"] = node_id
            r["node_name"] = node_name
            node_id = ""
            node_name = ""
          end
          !match
        end 
      end

      response.set_data(*filtered)
      response.render_table(:ps_data)
    end



    desc "grep LOG-PATH NODE-ID-PATTERN GREP-PATTERN [--first]","Grep log from multiple nodes. --first option returns first match (latest log entry)."
    method_option :first, :type => :boolean, :default => false
    def grep(context_params) 
      if context_params.is_there_identifier?(:node)
        mapping = [:workspace_id!,:option_1!,:node_id!,:option_2!]
      else
        mapping = [:workspace_id!,:option_1!,:option_2!,:option_3!]
      end

      workspace_id,log_path,node_pattern,grep_pattern = context_params.retrieve_arguments(mapping,method_argument_names)
         
      begin
        post_body = {
          :assembly_id         => workspace_id,
          :subtype             => 'instance',
          :log_path            => log_path,
          :node_pattern        => node_pattern,
          :grep_pattern        => grep_pattern,
          :stop_on_first_match => options.first?
        }

        response = post rest_url("assembly/initiate_grep"), post_body

        unless response.ok?
          raise DTK::Client::DtkError, "Error while getting log from server. Message: #{response['errors'][0]['message'].nil? ? 'There was no successful response.' : response['errors'].first['message']}"
        end

        action_results_id = response.data(:action_results_id)
        action_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => true,
          :disable_post_processing => true
        }

        # number of re-tries
        3.downto(1) do
          response = post(rest_url("assembly/get_action_results"),action_body)

          # server has found an error
          unless response.data(:results).nil?
            if response.data(:results)['error']
              raise DTK::Client::DtkError, response.data(:results)['error']
            end
          end

          break if response.data(:is_complete)

          sleep(1)
        end

        raise DTK::Client::DtkError, "Error while logging there was no successful response after 3 tries." unless response.data(:is_complete)
        
        console_width = ENV["COLUMNS"].to_i

        response.data(:results).each do |r|
          raise DTK::Client::DtkError, r[1]["error"] if r[1]["error"]

          message_colorized = DTK::Client::OsUtil.colorize(r[0].inspect, :green)

          if r[1]["output"].empty?
            puts "NODE-ID #{message_colorized} - Log does not contain data that matches you pattern #{grep_pattern}!" 
          else
            puts "\n"
            console_width.times do
              print "="
            end
            puts "NODE-ID: #{message_colorized}\n"
            puts "Log output:\n"
            puts r[1]["output"].gsub(/`/,'\'')
          end
        end
      rescue DTK::Client::DtkError => e
        raise e
      end
    end





    desc "tail NODE-ID LOG-PATH [REGEX-PATTERN] [--more]","Tail specified number of lines from log"
    method_option :more, :type => :boolean, :default => false
    def tail(context_params)
      if context_params.is_there_identifier?(:node)
        mapping = [:workspace_id!,:node_id!,:option_1!,:option_2]
      else
        mapping = [:workspace_id!,:option_1!,:option_2!,:option_3]
      end
      
      workspace_id,node_identifier,log_path,grep_option = context_params.retrieve_arguments(mapping,method_argument_names)
     
      last_line = nil
      begin

        file_path = File.join('/tmp',"dtk_tail_#{Time.now.to_i}.tmp")
        tail_temp_file = File.open(file_path,"a")

        file_ready = false

        t1 = Thread.new do
          while true
            post_body = {
              :assembly_id     => workspace_id,
              :subtype         => 'instance',
              :start_line      => last_line,
              :node_identifier => node_identifier,
              :log_path        => log_path,
              :grep_option     => grep_option
            }

            response = post rest_url("assembly/initiate_get_log"), post_body

            unless response.ok?
              raise DTK::Client::DtkError, "Error while getting log from server, there was no successful response."
            end

            action_results_id = response.data(:action_results_id)
            action_body = {
              :action_results_id => action_results_id,
              :return_only_if_complete => true,
              :disable_post_processing => true
            }

            # number of re-tries
            3.times do
              response = post(rest_url("assembly/get_action_results"),action_body)

              # server has found an error
              unless response.data(:results).nil?
                if response.data(:results)['error']
                  raise DTK::Client::DtkError, response.data(:results)['error']
                end
              end

              break if response.data(:is_complete)

              sleep(1)
            end

            raise DTK::Client::DtkError, "Error while logging there was no successful response after 3 tries." unless response.data(:is_complete)

            # due to complicated response we change its formating
            response = response.data(:results).first[1]

            unless response["error"].nil?
              raise DTK::Client::DtkError, response["error"]
            end

            # removing invalid chars from log
            output = response["output"].gsub(/`/,'\'')

            unless output.empty?
              file_ready = true
              tail_temp_file << output 
              tail_temp_file.flush
            end

            last_line = response["last_line"]
            sleep(LOG_SLEEP_TIME_W)
          end
        end

        t2 = Thread.new do
          # ramp up time
          begin
            if options.more?
              system("tail -f #{file_path} | more")
            else
              # needed ramp up time for t1 to start writting to file
              while not file_ready
                sleep(0.5)
              end
              system("less +F #{file_path}")
            end
          ensure
            # wheter application resolves normaly or is interrupted
            # t1 will be killed
            t1.exit()
          end
        end
        
        t1.join()
        t2.join()
      rescue Interrupt
        t2.exit()
      rescue DTK::Client::DtkError => e
        t2.exit()
        raise e
      end
    end

  end
end