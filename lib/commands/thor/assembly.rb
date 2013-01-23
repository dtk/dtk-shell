require 'rest_client'
require 'json'
require 'colorize'
dtk_require_from_base("dtk_logger")
dtk_require_from_base("util/os_util")
dtk_require_common_commands('thor/task_status')
dtk_require_common_commands('thor/set_required_params')

LOG_SLEEP_TIME   = Config::Configuration.get(:tail_log_frequency)
DEBUG_SLEEP_TIME = Config::Configuration.get(:debug_task_frequency)

module DTK::Client
  class Assembly < CommandBaseThor

    no_tasks do
      include TaskStatusMixin
      include SetRequiredParamsMixin
    end

    def self.pretty_print_cols()
      PPColumns.get(:assembly)
    end

    def self.valid_child?(name_of_sub_context)
      return [:node].include?(name_of_sub_context.to_sym)
    end

    def self.get_supported_enteties
      return [:node, :component, :attribute]
    end

    def self.validation_list(hashed_args)
      response = get_cached_response(:assembly, "assembly/list", {:subtype  => 'instance'})

      return response
    end

    desc "ASSEMBLY-NAME/ID promote-to-library", "Update or create library assembly using workspace assembly"
    def promote_to_library(hashed_args)
      assembly_id = CommandBaseThor.retrieve_arguments([:assembly_id],hashed_args)
      post_body = {
        :assembly_id => assembly_id
      }

      response = post rest_url("assembly/promote_to_library"), post_body
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :library
      
      return response
    end

    desc "ASSEMBLY-NAME/ID start [NODE-ID-PATTERN]", "Starts all assembly's nodes,  specific nodes can be selected via node id regex."
    def start(hashed_args)
      if CommandBaseThor.is_there_id?(:node_id, hashed_args)
        mapping = [:assembly_id,:node_id]
      else
        mapping = [:assembly_id,:option_1]
      end

      assembly_id, node_pattern = CommandBaseThor.retrieve_arguments(mapping,hashed_args)

      assembly_start(assembly_id, node_pattern)
    end

    desc "ASSEMBLY-NAME/ID stop [NODE-ID-PATTERN]", "Stops all assembly's nodes, specific nodes can be selected via node id regex."
    def stop(hashed_args)
      if CommandBaseThor.is_there_id?(:node_id, hashed_args)
        mapping = [:assembly_id,:node_id]
      else
        mapping = [:assembly_id,:option_1]
      end

      assembly_id, node_pattern = CommandBaseThor.retrieve_arguments(mapping,hashed_args)

      assembly_stop(assembly_id, node_pattern)
    end


    desc "ASSEMBLY-NAME/ID create-new-template SERVICE-MODULE-NAME ASSEMBLY-TEMPLATE-NAME", "Create a new assembly template from workspace assembly" 
    def create_new_template(hashed_args)
      assembly_id, service_module_name, assembly_template_name = CommandBaseThor.retrieve_arguments([:assembly_id,:option_1,:option_2],hashed_args)
      post_body = {
        :assembly_id => assembly_id,
        :service_module_name => service_module_name,
        :assembly_template_name => assembly_template_name
      }
      response = post rest_url("assembly/create_new_template"), post_body
      # when changing context send request for getting latest assembly_templates instead of getting from cache
      @@invalidate_map << :assembly_template

      return response
    end
    
    desc "ASSEMBLY-NAME/ID converge [-m COMMIT-MSG]", "Converges assembly instance"
    method_option "commit_msg",:aliases => "-m" ,
      :type => :string, 
      :banner => "COMMIT-MSG",
      :desc => "Commit message"
    def converge(hashed_args)
      assembly_id = CommandBaseThor.retrieve_arguments([:assembly_id],hashed_args)

      # create task
      post_body = {
        :assembly_id => assembly_id
      }

      post_body.merge!(:commit_msg => options.commit_msg) if options.commit_msg

      response = post rest_url("assembly/create_task"), post_body
      return response unless response.ok?

      # execute task
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    desc "ASSEMBLY-NAME/ID add EXTENSION-TYPE [-n COUNT]", "Adds a sub assembly template to the assembly"
    method_option "count",:aliases => "-n" ,
      :type => :string, #integer 
      :banner => "COUNT",
      :desc => "Number of sub-assemblies to add"
    def add(hashed_args)
      assembly_id,service_add_on_name = CommandBaseThor.retrieve_arguments([:assembly_id,:option_1],hashed_args)

      # create task
      post_body = {
        :assembly_id => assembly_id,
        :service_add_on_name => service_add_on_name
      }

      post_body.merge!(:count => options.count) if options.count

      response = post rest_url("assembly/add_sub_assembly"), post_body
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly

      return response
    end

    desc "ASSEMBLY-NAME/ID possible-extensions", "Lists the possible extensions to the assembly" 
    def possible_extensions(hashed_args)
      assembly_id = CommandBaseThor.retrieve_arguments([:assembly_id],hashed_args)

      post_body = {
        :assembly_id => assembly_id
      }
      response = post(rest_url("assembly/list_possible_add_ons"),post_body)
      response.render_table(:service_add_on)
    end

    desc "ASSEMBLY-NAME/ID task-status [--wait]", "Task status of running or last assembly task"
    method_option :wait, :type => :boolean, :default => false
    def task_status(hashed_args)
      assembly_id = CommandBaseThor.retrieve_arguments([:assembly_id],hashed_args)
      task_status_aux(assembly_id,:assembly,options.wait?)
    end

    desc "ASSEMBLY-NAME/ID run-smoketests", "Run smoketests associated with assembly instance"
    def run_smoketests(hashed_args)
      assembly_id = CommandBaseThor.retrieve_arguments([:assembly_id],hashed_args)
      post_body = {
        :assembly_id => assembly_id
      }
      # create smoke test
      response = post rest_url("assembly/create_smoketests_task"), post_body
      return response unless response.ok?
      # execute
      task_id = response.data(:task_id)
      post rest_url("task/execute"), "task_id" => task_id
    end

    #TODO: put in flag to control detail level
    desc "[ASSEMBLY-NAME/ID] list [nodes|components|attributes|tasks] [FILTER] [--list] ","List assemblies, nodes, components, attributes or tasks associated with assembly."
    method_option :list, :type => :boolean, :default => false
    def list(hashed_args)
      assembly_id, about, filter = CommandBaseThor.retrieve_arguments([:assembly_id,:option_1,:option_2],hashed_args)

      if CommandBaseThor.is_there_task?(:node,hashed_args)
        about ||= 'nodes'
      end

      if assembly_id.nil?
        data_type = :assembly
        response = post rest_url("assembly/list"), {:subtype  => 'instance'}

        # set render view to be used
        response.render_table(data_type) unless options.list?
        
        return response
      else
        about ||= "none"
        #TODO: need to detect if two args given by list [nodes|components|tasks FILTER
        #can make sure that first arg is not one of [nodes|components|tasks] but these could be names of assembly (although unlikely); so would then need to
        #look at form of FILTER
        response = ""

        post_body = {
          :assembly_id => assembly_id,
          :subtype     => 'instance',
          :about       => about,
          :filter      => filter
        }

        case about
          when "nodes":
            data_type = :node
          when "components":
            data_type = :component
          when "attributes":
            data_type = :attribute
          when "tasks":
            data_type = :task
          else
            raise DTK::Client::DtkError, "Not supported type '#{about}' for given command."
        end

        response = post rest_url("assembly/info_about"), post_body

           
        # set render view to be used
        unless options.list?
          response.render_table(data_type)
        end
               
        return response
      end
    end

    desc "list-smoketests ASSEMBLY-ID","List smoketests on asssembly"
    def list_smoketests(hashed_args)
      assembly_id = CommandBaseThor.retrieve_arguments([:assembly_id],hashed_args)

      post_body = {
        :assembly_id => assembly_id
      }
      post rest_url("assembly/list_smoketests"), post_body
    end

    desc "ASSEMBLY-NAME/ID info", "Return info about assembly instance identified by name/id"
    def info(hashed_args)
      assembly_id, node_id = CommandBaseThor.retrieve_arguments([:assembly_id,:node_id],hashed_args)

      # TODO: Add node id filter on server side      
      post_body = {
        :assembly_id => assembly_id,
        :subtype => :instance
      }
      post rest_url("assembly/info"), post_body
    end

    desc "delete-and-destroy ASSEMBLY-ID [-y]", "Delete assembly instance, termining any nodes taht have been spun up"
    method_option :force, :aliases => '-y', :type => :boolean, :default => false
    def delete_and_destroy(hashed_args)
      assembly_id = CommandBaseThor.retrieve_arguments([:assembly_id],hashed_args)

      unless options.force?
        # Ask user if really want to delete assembly, if not then return to dtk-shell without deleting
        return unless Console.confirmation_prompt("Are you sure you want to delete and destroy assembly '#{assembly_id}' and its nodes?")
      end

      post_body = {
        :assembly_id => assembly_id,
        :subtype => :instance
      }

      response = post rest_url("assembly/delete"), post_body
      # when changing context send request for getting latest assemblies instead of getting from cache
      @@invalidate_map << :assembly

      return response
    end

    desc "ASSEMBLY-NAME/ID set ATTRIBUTE-PATTERN VALUE", "Set target assembly attributes"
    def set(hashed_args)
      assembly_id, pattern, value = CommandBaseThor.retrieve_arguments([:assembly_id,:option_1,:option_2],hashed_args)
      post_body = {
        :assembly_id => assembly_id,
        :pattern => pattern,
        :value => value
      }
      #TODO: have this return format like assembly show attributes with subset of rows that gt changed
      post rest_url("assembly/set_attributes"), post_body
    end

    desc "create-jenkins-project ASSEMBLY-TEMPLATE-NAME/ID", "Create Jenkins project for assembly template"
    def create_jenkins_project(hashed_args)
      assembly_id  = CommandBaseThor.retrieve_arguments([:assembly_id],hashed_args)
      #require put here so dont necessarily have to install jenkins client gems
      dtk_require_from_base('command_helpers/jenkins_client')
      post_body = {
        :assembly_id => assembly_id,
        :subtype => :template
      }
      response = post(rest_url("assembly/info"),post_body)
      return response unless response.ok?
      assembly_id,assembly_name = response.data(:id,:display_name)
      #TODO: modify JenkinsClient to use response wrapper
      JenkinsClient.create_assembly_project?(assembly_name,assembly_id)
      nil
    end

    desc "ASSEMBLY-NAME/ID add-component NODE-ID COMPONENT-TEMPLATE-NAME/ID", "Add component template to assembly node"
    def add_component(hashed_args)
    
      # If method is invoked from 'assembly/node' level retrieve node_id argument 
      # directly from active context
      if CommandBaseThor.is_there_id?(:node_id,hashed_args)
        mapping = [:assembly_id,:node_id,:option_1]
      else
        # otherwise retrieve node_id from command options
        mapping = [:assembly_id,:option_1,:option_2]
      end

      assembly_id,node_id,component_template_id = CommandBaseThor.retrieve_arguments(mapping,hashed_args)
      
      post_body = {
        :assembly_id => assembly_id,
        :node_id => "#{assembly_id}::#{node_id}",
        :component_template_id => component_template_id
      }

      post rest_url("assembly/add_component"), post_body
    end

    desc "ASSEMBLY-NAME/ID delete-component COMPONENT-ID","Delete component from assembly"
    def delete_component(hashed_args)
      assembly_id,node_id,component_id = CommandBaseThor.retrieve_arguments([:assembly_id,:node_id,:option_1],hashed_args)

      # TODO: Add method with constraint Node ID on server side
      post_body = {
        :assembly_id => assembly_id,
        :component_id => component_id
      }
      response = post(rest_url("assembly/delete_component"),post_body)
    end


    desc "ASSEMBLY-NAME/ID get-netstats", "Get netstats"
    def get_netstats(hashed_args)
      assembly_id,node_id = CommandBaseThor.retrieve_arguments([:assembly_id,:node_id],hashed_args)

      # TODO: Add support for node ID on this methods on server side
      post_body = {
        :assembly_id => assembly_id
      }

      response = post(rest_url("assembly/initiate_get_netstats"),post_body)
      return response unless response.ok?

      action_results_id = response.data(:action_results_id)
      end_loop, response, count, ret_only_if_complete = false, nil, 0, true

      until end_loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => ret_only_if_complete,
          :disable_post_processing => false
        }
        response = post(rest_url("assembly/get_action_results"),post_body)
        count += 1
        if count > GetNetStatsTries or response.data(:is_complete)
          end_loop = true
        else
          #last time in loop return whetever is teher
          if count == GetNetStatsTries
            ret_only_if_complete = false
          end
          sleep GetNetStatsSleep
        end
      end

      #TODO: needed better way to render what is one of teh feileds which is any array (:results in this case)
      response.set_data(*response.data(:results))
      response.render_table(:netstat_data)
    end
    GetNetStatsTries = 6
    GetNetStatsSleep = 0.5

    desc "ASSEMBLY-NAME/ID set-required-params", "Interactive dialog to set required params that are not currently set"
    def set_required_params(hashed_args)
      assembly_id = CommandBaseThor.retrieve_arguments([:assembly_id],hashed_args)
      set_required_params_aux(assembly_id,:assembly,:instance)
    end

    desc "ASSEMBLY-NAME/ID tail NODE-ID LOG-PATH [REGEX-PATTERN] [--more]","Tail specified number of lines from log"
    method_option :more, :type => :boolean, :default => false
    def tail(hashed_args)
      if CommandBaseThor.is_there_id?(:node_id, hashed_args)
        mapping = [:assembly_id,:node_id,:option_1,:option_2]
      else
        mapping = [:assembly_id,:option_1,:option_2,:option_3]
      end
      
      assembly_id,node_identifier,log_path,grep_option = CommandBaseThor.retrieve_arguments(mapping,hashed_args)
     
      last_line = nil
      begin

        file_path = File.join('/tmp',"dtk_tail_#{Time.now.to_i}.tmp")
        tail_temp_file = File.open(file_path,"a")

        file_ready = false

        t1 = Thread.new do
          while true
            post_body = {
              :assembly_id     => assembly_id,
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
            sleep(LOG_SLEEP_TIME)
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

    desc "ASSEMBLY-NAME/ID grep LOG-PATH NODE-ID-PATTERN GREP-PATTERN [--first_match]","Grep log from multiple nodes"
    method_option :first_match, :type => :boolean, :default => false
    def grep(hashed_args)
      
    if CommandBaseThor.is_there_id?(:node_id,hashed_args)
      mapping = [:assembly_id,:option_1,:node_id,:option_2]
    else
      mapping = [:assembly_id,:option_1,:option_2,:option_3]
    end

    assembly_id,log_path,node_pattern,grep_pattern = CommandBaseThor.retrieve_arguments(mapping, hashed_args)
       
    begin
      post_body = {
        :assembly_id         => assembly_id,
        :subtype             => 'instance',
        :log_path            => log_path,
        :node_pattern        => node_pattern,
        :grep_pattern        => grep_pattern,
        :stop_on_first_match => options.first_match?
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

        if r[1]["output"].empty?
          puts "NODE-ID #{r[0].inspect.colorize(:green)} - Log does not contain data that matches you pattern #{grep_pattern}!" 
        else
          puts "\n"
          console_width.times do
            print "="
          end
          puts "NODE-ID: #{r[0].inspect.colorize(:green)}\n"
          puts "Log output:\n"
          puts r[1]["output"].gsub(/`/,'\'')
        end
      end
        
      rescue DTK::Client::DtkError => e
        raise e
      end
    end
    
  end
end

