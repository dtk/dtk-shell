class DTK::Client::Execute
  class Iterate
    class ResultStore < Hash
      def store_result(result,result_var=nil)
        self[result_var||default_var()] = result
      end
      
     private
      def default_var
        DefaultVar
      end
      DefaultVar = :result
    end
  end
end
