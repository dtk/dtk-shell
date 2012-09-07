require File.expand_path('../commands/thor/dtk', File.dirname(__FILE__))
require File.expand_path('../auxiliary', File.dirname(__FILE__))

module DTK
  module Shell
    class Context

      include DTK::Client::Aux

      ALL_TASKS = DTK::Client::Dtk.task_names
      

      def initialize
        @context = {}

        @context.store('dtk',ALL_TASKS.sort)

        ALL_TASKS.each do |task_name|
          next if task_name.eql? "help"

          file_name = task_name.gsub('-','_')
          require File.expand_path("../commands/thor/#{file_name}", File.dirname(__FILE__))
          
          @context.store(task_name, get_command_class(file_name).task_names.sort)
        end
      end

      def dtk_tasks
        @context['dtk']
      end

      def sub_tasks_names(name=nil)

        return @context[name.to_s] unless name.nil?

        all_tasks = []
        @context.each_value { |v| all_tasks.concat(v)}
        return all_tasks.uniq.sort
      end

      private

      def get_command_class(file_name)
        Object.const_get('DTK').const_get('Client').const_get(cap_form(file_name))
      end

    end
  end
end


