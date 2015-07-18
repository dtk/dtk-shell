module DTK::Client; class TaskStatus::StreamMode::Element
  class HierarchicalTask < ::Hash
    def initialize(stage_subtasks)
      super()
      @subtasks      = stage_subtasks
      @leaf_subtasks = leaf_subtasks
    end

    def self.steps(subtasks)
      Steps.new(subtasks).steps
    end

    def self.results?(subtasks)
      Results.new(subtasks).results?
    end

    private

    def leaf_subtasks
    end


    class Steps < self
      def steps
      end
    end
    
    class Results < self
      def results?
      end
    end
  end
end; end
