module DTK; module Client
  class CommandBaseThor
    module CommonOptionDefsClassMixin
      def version_method_option()
        method_option "version",:aliases => "-v",
        :type => :string, 
        :banner => "VERSION",
        :desc => "Version"
      end
    end
  end
end; end
