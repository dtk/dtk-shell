require 'hirb'

module DTK::Client
  module TaskStatusMixin
    def task_status_aux(id, type, opts={})
        if opts[:wait]
          # there will be infinite loop until intereputed with CTRL+C
          begin
            response = nil
            loop do
              response = task_status_aux_post(id, type, opts)
              raise DTK::Client::DtkError, "[ERROR] #{response['errors'].first['message']}." if response["status"].eql?('notok')

              # stop pulling when top level task succeds, fails or timeout
              if response and response.data and response.data.first
                #TODO: may fix in server, but now top can have non executing state but a concurrent branch can execute; so
                #chanding bloew for time being
                #break unless response.data.first["status"].eql? "executing"
                # TODO: There is bug where we do not see executing status on start so we have to wait until at
                # least one 'successed' has been found

                top_task_failed = response.data.first['status'].eql?('failed')
                is_pending   = (response.data.select {|r|r["status"].nil? }).size > 0
                is_executing = (response.data.select {|r|r["status"].eql? "executing"}).size > 0
                is_failed    = (response.data.select {|r|r["status"].eql? "failed"}).size > 0
                is_cancelled = response.data.first["status"].eql?("cancelled")

                # commented out because of DTK-1804
                # when some of the converge tasks fail, stop task-status --wait and set task status to '' for remaining tasks which are not executed
                # if is_failed
                  # response.data.each {|r| (r["status"] = "") if r["status"].eql?("executing")}
                  # is_cancelled = true
                # end
                is_cancelled = true if top_task_failed

                unless (is_executing || is_pending) && !is_cancelled
                  system('clear')
                  response.print_error_table = true
                  response.render_table(:task_status)
                  return response
                end
              end

              response.render_table(:task_status)
              system('clear')
              response.render_data(true)

              Console.wait_animation("Watching '#{type}' task status [ #{DEBUG_SLEEP_TIME} seconds refresh ] ", DEBUG_SLEEP_TIME)
            end
          rescue Interrupt => e
            puts ""
            # this tells rest of the flow to skip rendering of this response
            response.skip_render = true unless response.nil?
          end
        else
          response = task_status_aux_post(id,type,opts)
          response.print_error_table = true
          response.render_table(:task_status)
        end
      end


      def follow_task_in_foreground(assembly_or_workspace_id)
        current_index = 1
        last_printed_index = 0
        success_indices = []

        loop do
          response = get_task_status(assembly_or_workspace_id, :assembly, :table)
          return response unless response.ok?

          current_tasks = response.data.select { |el| el['index'] == current_index }
          main_task     = current_tasks.find { |el| el['sub_index'].nil? }

          # this means this is last tasks
          unless main_task
            print_succeeded_tasks(response.data, success_indices)
            return Response::Ok.new()
          end

          case main_task['status']
          when 'executing'
            if (last_printed_index != current_index)
              OsUtil.clear_screen
              print_succeeded_tasks(response.data, success_indices)
              print_tasks(current_tasks)
              last_printed_index = current_index
            end
          when 'succeeded'
            success_indices << current_index
            current_index  += 1
          when nil
            # ignore
          else
            errors = current_tasks.collect { |ct| ct['errors'] }.compact
            error_msg = errors.collect { |err| err['message'] }.uniq.join(', ')
            raise DTK::Client::DtkError, "We've run into an error on task '#{main_task['type']}' status '#{main_task['status']}', error: #{error_msg}"
          end

          sleep(5)
        end
      end

      def get_task_status(id, type, format = :list)
        id_sym = "#{type}_id".to_sym
        post_body = {
          id_sym => id,
          :format => format
        }
        post rest_url("#{type}/task_status"), post_body
      end

      def list_task_info_aux(type, id)
        response = get_task_status(id, type, :list)

        raise DTK::Client::DtkError, "[SERVER ERROR] #{response['errors'].first['message']}." if response["status"].eql?('notok')

        response.override_command_class("list_task")
        puts response.render_data
      end

     private

      def parse_date(string_date)
        string_date.nil? ? (' ' * 17) : DateTime.parse(string_date).strftime('%H:%M:%S %d/%m/%y')
      end

      def append_to(number_of_chars, value)
        value ||= ''
        value.strip!
        appending_str = ' ' * (number_of_chars - value.size)
        value.insert(0, appending_str)
      end

      def print_tasks(tasks)
        hirb_options = { :headers => nil, :filters => [Proc.new { |a| append_to(25, a) }, Proc.new { |a| append_to(15, a)}, Proc.new { |a| append_to(15, a)}, Proc.new { |a| append_to(8, a)}], :unicode => true, :description => false }


        tasks.each do |task|
          node_name = task['node'] ? task['node']['name'] : ''

          puts Hirb::Helpers::AutoTable.render([[task['type'], task['status'], node_name, task['duration'], parse_date(task['started_at']), parse_date(task['ended_at'])]], hirb_options)
        end
      end

      def print_succeeded_tasks(tasks, success_indices)
        succeeded_tasks = tasks.select { |task| success_indices.include?(task['index']) }
        print_tasks(succeeded_tasks)
      end

      def task_status_aux_post(id, type, opts={})
        id_field = "#{type}_id".to_sym
        post_body_hash = {
          id_field                => id,
          :format                 => :table,
          :summarize_node_groups? => opts[:summarize]
        }
        post rest_url("#{type}/task_status"), PostBody.new(post_body_hash)
      end
    end

end
