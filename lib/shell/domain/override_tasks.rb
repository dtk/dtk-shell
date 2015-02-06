module DTK
  module Shell

    class CachedTasks < Hash
    end

    class OverrideTasks < Hash

      attr_accessor :completed_tasks
      attr_accessor :always_load_list


      # help_item (Thor printable task), structure:
      # [0] => task defintion
      # [1] => task description
      # [2] => task name

      # overriden_task (DTK override task), structure:
      # [0] => task name
      # [1] => task defintion
      # [2] => task description

      # using 'always load listed' to skip adding task to completed tasks e.g load utils for workspace and workspace_node
      def initialize(hash=nil, always_load_listed=[])
        super(hash)
        @completed_tasks = []
        @always_load_list = always_load_listed
        self.merge!(hash)
      end

      # returns true if there are overrides for tasks on first two levels.
      def are_there_self_override_tasks?
        return (self[:all][:self] || self[:command_only][:self] || self[:identifier_only][:self])
      end

      def check_help_item(help_item, is_command)
        command_tasks, identifier_tasks = get_all_tasks(:self)
        found = []

        if is_command
          found = command_tasks.select { |o_task| o_task[0].eql?(help_item[2]) }
        else
          found = identifier_tasks.select { |o_task| o_task[0].eql?(help_item[2]) }
        end

        # if we find self overriden task we remove it
        # [found.first[1],found.first[2],found.first[0]] => we convert from o_task structure to thor help structure
        return found.empty? ? help_item : [found.first[1],found.first[2],found.first[0]]
      end

      # returns 2 arrays one for commands and next one for identifiers
      def get_all_tasks(child_name)
        command_o_tasks, identifier_o_tasks = [], []
        command_o_tasks    = (self[:all][child_name]||[]) + (self[:command_only][child_name]||[])
        identifier_o_tasks = (self[:all][child_name]||[]) + (self[:identifier_only][child_name]||[])
        return command_o_tasks, identifier_o_tasks
      end

      def is_completed?(child_name)
        # do not add task to completed if explicitly said to always load that task
        return false if @always_load_list.include?(child_name)
        @completed_tasks.include?(child_name)
      end

      def add_to_completed(child_name)
        @completed_tasks << child_name
      end
    end

  end
end
