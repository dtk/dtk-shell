require File.expand_path('../commands/thor/dtk', File.dirname(__FILE__))
require File.expand_path('../auxiliary', File.dirname(__FILE__))

module DTK
  module Shell
    class Context

      include DTK::Client::Aux

      ALL_TASKS = DTK::Client::Dtk.task_names
      @context = {}

      def initialize
        ALL_TASKS.each do |task_name|
          next if task_name.eql? "help"

          file_name = task_name.gsub('-','_')
          require File.expand_path("../commands/thor/#{file_name}", File.dirname(__FILE__))
          

          puts @context[file_name.to_sym]
        end
      end

      def sub_tasks_names(names)
        names.each do |class_name|
          ALL_TASKS.each do |name|
            if name.eql? class_name
            end
          end
        end
      end

      private

      def get_command_class(file_name)
        Object.const_get('DTK').const_get('Client').const_get(cap_form(file_name)
      end

    end
  end
end


