class Thor
  class Options < Arguments #:nodoc:

    protected

      def parse_boolean(switch)
        if current_is_value?
          if ["true", "TRUE", "t", "T", true].include?(peek)
            # shift
            true
          elsif ["false", "FALSE", "f", "F", false].include?(peek)
            # shift
            true
          else
            true
          end
        else
          @switches.key?(switch) || !no_or_skip?(switch)
        end
      end
  end
end