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

    #TODO: probably move this
    class PostBody < Hash
      def initialize(raw={})
        super()
        unless raw.empty?
          replace(convert(raw))
        end
      end
      def merge(raw)
        super(convert(raw))
      end
      def merge!(raw)
        super(convert(raw))
      end

     private
      def convert(raw)
        raw.inject(Hash.new) do |h,(k,v)|
          if non_null_var = is_only_non_null_var?(k)
            v.nil? ? h : h.merge(non_null_var => v)
          else
            h.merge(k => v)
          end
        end
      end
      def is_only_non_null_var?(k)
        if k.to_s =~ /\?$/
          k.to_s.gsub(/\?$/,'').to_sym
        end
      end
    end
  end
end
