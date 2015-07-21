module DTK::Client; class TaskStatus::StreamMode::Element::HierarchicalTask
  class Steps
    class Components < self
      def initialize(element, hash)
        super
        pp [:component_steps, hash]
        @component_names = (hash['components'] || []).map { |cmp| cmp['name'] }.compact
      end

      def render_steps(steps)
        steps.each { |step| step.render }
      end
      
      def render
        
      end
    end
  end

end; end
