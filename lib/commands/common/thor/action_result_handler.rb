module DTK
  module Client
    module ActionResultHandler

      def print_action_results(action_results_id, number_of_retries=8)
        response = action_results(action_results_id, number_of_retries)

        if response.ok? && response.data['results']
          response.data['results'].each do |k,v|
            if v['error']
              OsUtil.print("#{v['error']} (#{k})", :red)
            else
              OsUtil.print("#{v['message']} (#{k})", :yellow)
            end
          end
        else
          OsUtil.print("Not able to process given request, we apologise for inconvenience", :red)
        end

        nil
      end

      def action_results(action_results_id, number_of_retries=8)
        action_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => true,
          :disable_post_processing => true
        }
        response = nil

        number_of_retries.times do
          response = post(rest_url("assembly/get_action_results"),action_body)

          # server has found an error
          unless response.data(:results).nil?
            if response.data(:results)['error']
              raise DTK::Client::DtkError, response.data(:results)['error']
            end
          end

          break if response.data(:is_complete)

          sleep(1.5)
        end

        response

      end
      
    end
  end
end