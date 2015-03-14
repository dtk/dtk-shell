class DTK::Client::Execute
  class Command::APICall
    class Map < Hash
      def initialize(hash={})
        super()
        replace(hash)
      end

      def translate(api_params={})
        if Rest::Post.matches?(type())
          Command::RestCall::Post.new(:path => path(),:body => translate_to_rest_body(api_params))
        else
          raise "Type in following map is not defined not defined: #{self.inspect}"
        end
      end

     private
      def translate_to_rest_body(api_params)
        body().inject(Hash.new) do |h,(k,v)|
          unless TranslationTerm.matches?(v)
            # this is a constant
            h.merge(k => v)
          else
            processed = false
            processed_v = nil 
            if Equal.matches?(v)
              processed = true
              if Equal::Required.matches?(v) and !api_params.has_key?(k)
                raise ErrorUsage.new("Missing key '#{k}' in params: #{api_params.ispect}")
              end
              processed_v = api_params[k]
            end
            unless processed
              raise "Cannot Process in '#{self.class}': key=#{k}; value=#{v.inspect}" 
            end
            h.merge(k => processed_v)
          end
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
