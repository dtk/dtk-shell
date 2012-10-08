require 'hirb'

module DTK
  module Shell

    # We will use this class to generate header for console which would be always present,
    # when activated. Hirb implementation will be used to display status information.

    class HeaderShell

      attr_accessor :active
      alias_method  :is_active?, :active

      def initialize
        @active = true
      end

      def print_header
        puts "*********************"
        puts "********************* #{Time.now} "
        puts "*********************"
      end


    end
  end
end