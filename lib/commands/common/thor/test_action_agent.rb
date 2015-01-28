module DTK::Client
  module TestActionAgent

    def test_agent_aux(context_params)
      service_id, node_id, bash_command = context_params.retrieve_arguments([:service_id!, :node_id!, :option_1!], method_argument_names)

      post_body = {
        :assembly_id  => service_id,
        :node_id      => node_id,
        :bash_command => bash_command
      }

      response = post(rest_url("assembly/initiate_action_agent"), post_body)
      return response unless response.ok?


      action_results_id = response.data(:action_results_id)
      response          = nil

      loop do
        post_body = {
          :action_results_id => action_results_id,
          :return_only_if_complete => true,
          :disable_post_processing => false
        }

        response = post(rest_url("assembly/get_action_results"),post_body)

        if response.data(:is_complete) || !response.ok?
          break
        else
          sleep(1)
        end
      end

      return response
    end
  end
end