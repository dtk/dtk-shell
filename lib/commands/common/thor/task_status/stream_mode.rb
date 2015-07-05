require 'hirb'
module DTK::Client
  class TaskStatus
    class StreamMode < self
      def task_status()
        current_index = 1
        last_printed_index = 0
        success_indices = []
        loop do
          response = task_status_post_call(:form => :stream_form)
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
            raise DtkError, "We've run into an error on task '#{main_task['type']}' status '#{main_task['status']}', error: #{error_msg}"
          end
          
          sleep(5)
        end
      end
      
     private
      def print_tasks(tasks)
        hirb_options = { 
          :headers => nil, 
          :filters => [Proc.new { |a| append_to(25, a) }, 
                       Proc.new { |a| append_to(15, a)}, 
                       Proc.new { |a| append_to(15, a)}, 
                       Proc.new { |a| append_to(8, a)}], 
          :unicode => true, 
          :description => false 
        }

        tasks.each do |task|
          node_name = task['node'] ? task['node']['name'] : ''
          
          puts Hirb::Helpers::AutoTable.render([[task['type'], task['status'], node_name, task['duration'], parse_date(task['started_at']), parse_date(task['ended_at'])]], hirb_options)
        end
      end

      def print_succeeded_tasks(tasks, success_indices)
        succeeded_tasks = tasks.select { |task| success_indices.include?(task['index']) }
        print_tasks(succeeded_tasks)
      end

      def parse_date(string_date)
        string_date.nil? ? (' ' * 17) : DateTime.parse(string_date).strftime('%H:%M:%S %d/%m/%y')
      end

      def append_to(number_of_chars, value)
        value ||= ''
        value.strip!
        appending_str = ' ' * (number_of_chars - value.size)
        value.insert(0, appending_str)
      end
    end
  end
end



