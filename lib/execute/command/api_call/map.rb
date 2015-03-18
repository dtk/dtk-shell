class DTK::Client::Execute
  class Command::APICall
    class Map < Hash
      def initialize(hash={})
        super()
        replace(hash)
      end

      def translate(api_params={},opts={})
        if Rest::Post.matches?(type())
          Command::RestCall::Post.new(:path => path(),:body => translate_to_rest_body(api_params,opts))
        else
          raise "Type in following map is not defined not defined: #{self.inspect}"
        end
      end

     private
      def translate_to_rest_body(api_params,opts)
        body().inject(Hash.new) do |h,(k,v)|
          # if TranslationTerm.matches is false then v is a constant
          processed_v = 
            if TranslationTerm.matches?(v)
              v.instance_form().translate(k,api_params,opts)
            else 
              v
            end
          h.merge(k => processed_v)
        end
      end

      def type()
        self[:type]
      end
      def path()
        self[:path]
      end
      def body()
        self[:body]
      end

    end
  end
end
