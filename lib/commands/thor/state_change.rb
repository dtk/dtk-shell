module DTK::Client
  class StateChange < CommandBaseThor
    desc "list","List pending state changes"
    def list(context_params)
      get rest_url("state_change/list_pending_changes")
    end
  end
end


