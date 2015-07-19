class DTK::Client::TaskStatus::StreamMode::Element::Stage
  module Render
    module Results
      def self.lines(results)
        (results || []).inject([]) do |a, result|
          a + result_lines(result)
        end
      end

      private

      def self.result_lines(result)
        ret = []
        return ret unless result
        if result.action_mode?
          ret << 'RESULTS:'
          ret = (result.action_results || ret).inject(ret) do |a, action_result|
            a + action_result_lines(action_result)
          end
          # do not need errors if have action results
        elsif errors = result.errors
          ret = (errors || ret).inject([]) do |a, error|
            a + error_lines(error)
          end
        end
        ret
      end

      private

      def error_lines(error)
        #TODO stub
        pp [:error,error]
        []
      end

      def self.action_result_lines(action_result)
        ret = []
        description = description?(action_result)
        return_code = action_result['status']
        stdout      = action_result['stdout']
        stderr      = action_result['stderr']
        ret << '--' 
        ret << description if description
        ret << "STATUS: #{return_code}" if return_code
        if stdout && !stdout.empty?
          ret << "STDOUT: #{stdout}"
        end
        if stderr && !stderr.empty?        
          ret << "STDERR: #{stderr}"
        end
        ret
      end

      def self.description?(action_result)
        if description = action_result['description']
          if match = description.match(/^(create )(.*)/)
            "ADD: #{match[2]}"
          else
            "RUN: #{description}"
          end
        end
      end

    end
  end
end
