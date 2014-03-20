module DTK
  module Client
    module ActionResultHandler

      def print_action_results(action_results_id, number_of_retries=3)
        response = action_results(action_results_id, number_of_retries)

        if response.ok? && response.data['results']
          el = response.data['results'].values.first
          if el['error']
            OsUtil.print(el['error'], :red)
          else
            OsUtil.print(el['message'], :yellow)
          end
        end

        nil
      end

      def action_results(action_results_id, number_of_retries=3)
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

          sleep(1)
        end

        response

      end
      
    end
  end
end