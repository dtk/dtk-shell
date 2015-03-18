class DTK::Client::Execute
  class ExecuteContext
    class ResultStore < Hash
      def store(result,result_index=nil)
        self[result_index||Index.last] = result
      end

      def get_last_result?()
        self[Index.last]
      end
      
      module Index
        def self.last()
          Last
        end
        Last = :last
      end
    end
  end
end
