require File.expand_path('../commands/thor/dtk', File.dirname(__FILE__))
require File.expand_path('../auxiliary', File.dirname(__FILE__))

module DTK
  module Shell
    class Context
      include DTK::Client::Aux

      ALL_TASKS = DTK::Client::Dtk.task_names
      
      def initialize
        @context = {}
        @conn    = DTK::Client::Conn.new()

        @context.store('dtk',ALL_TASKS.sort)

        ALL_TASKS.each do |task_name|
          next if task_name.eql? "help"

          file_name = task_name.gsub('-','_')
          require File.expand_path("../commands/thor/#{file_name}", File.dirname(__FILE__))
          
          # gets thor command class and then all the task names for that command
          @context.store(task_name, get_command_class(file_name).task_names.sort)
        end
      end

      def dtk_tasks
        @context['dtk']
      end

      def sub_tasks_names(name=nil)
        return @context[name.to_s] unless name.nil?

        # returns root tasks
        dtk_tasks
      end

      # calls 'valid_id?' method in Thor class to validate ID/NAME
      def valid_id?(thor_command_name,value)
        command_clazz = get_command_class(thor_command_name)
        if command_clazz.respond_to?(:valid_id?)
          return command_clazz.valid_id?(value,@conn)
        end

        # if not implemented we are going to let it in the context
        # TODO: Removed this 'put' after this has been implemented where needed
        puts "[DEV] Implement 'valid_id?' method for thor command class: #{thor_command_name} "
        return false
      end

      private

      def get_command_class(command_name)
        Object.const_get('DTK').const_get('Client').const_get(cap_form(command_name))
      end

    end
  end
end


