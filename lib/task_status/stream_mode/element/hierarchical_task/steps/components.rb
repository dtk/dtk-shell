module DTK::Client; class TaskStatus::StreamMode::Element::HierarchicalTask
  class Steps
    class Components < self
      def initialize(element, hash)
        super
        @component_names = (hash['components'] || []).map { |cmp| cmp['name'] }.compact
      end

      attr_reader :component_names

      def render_steps(steps)
        step = steps.first
        if steps.size ==  1 and step.component_names.size == 1 
          render_line "CONVERGE COMPONENT: #{step.component_term(step.component_names.first)}"
        else
          render_line 'CONVERGE COMPONENTS:'
          steps.each do |step| 
            @component_names.each do |component_name|
              render_line  step.component_term(component_name), :tabs => 1
            end
          end
        end
      end
      
      def component_term(component_name)
        ret = ''
        if node_term = node_term?
          ret << "#{node_term}/"
        end
        ret << component_name
        ret
      end
    end
  end

end; end
