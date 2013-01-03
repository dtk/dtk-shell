module DTK::Client
  module PushToRemoteMixin

    ##
    #
    # module_type: will be :component_module or :service_module

    def push_to_remote_aux(module_type,module_id)
      id_field = "#{module_type}_id"
      post_body = {
        id_field => module_id
      }

      response = post(rest_url("#{module_type}/check_remote_auth"),post_body)
      #TODO: stub
      return response
      return response unless response.ok?
    end

  end
end
