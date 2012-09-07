module DTK
  module Shell
    class Context

      def intialize

        DTK::Client::Dtk.task_names.each do |class_name|
  puts " >> #{class_name}"
  require File.expand_path("../lib/commands/thor/#{class_name.gsub('-','_')}", File.dirname(__FILE__))
  
      end

      def sub_tasks_names
      end

    end
  end
end


