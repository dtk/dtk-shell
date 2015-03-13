class DTK::Client::Execute
  class Iterate
    class ResultStore < Hash
      def self.default_var
        DefaultVar
      end
      DefaultVar = :result

      def store_result(result,result_var)
        self[result_var] = result
      end
    end
  end
end
