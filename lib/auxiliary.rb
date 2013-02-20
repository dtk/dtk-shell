module DTK
  module Client
    module Auxiliary
      def cap_form(x)
        x.gsub('-','_').to_s.split("_").map{|t|t.capitalize}.join("")
      end

      def snake_form(command_class,seperator="_")
        command_class.to_s.gsub(/^.*::/, '').gsub(/Command$/,'').scan(/[A-Z][a-z]+/).map{|w|w.downcase}.join(seperator)
      end
    end
  end
end
