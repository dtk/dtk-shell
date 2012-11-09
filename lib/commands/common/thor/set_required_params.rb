module DTK::Client
  module SetRequiredParamsMixin
    def set_required_params_aux(id,type,subtype=nil)
      id_field = "#{type}_id".to_sym
      post_body = {
        id_field => id,
        :subtype     => 'instance',
        :filter      => 'required_unset_attributes'
      }
      post_body.merge!(:subtype => subtype.to_s) if subtype
      response = post rest_url("#{type}/get_attributes"), post_body
      return response unless response.ok?
      missing_params = response.data
      if missing_params.empty?
        response.set_data('Message' => "No parameters to set.")
        response
      else
        param_bindings = DTK::Shell::InteractiveWizard.new.resolve_missing_params(missing_params)
        post_body = {
          id_field => id,
          :av_pairs_hash => param_bindings.inject(Hash.new){|h,r|h.merge(r[:id] => r[:value])}
        }
        response = post rest_url("#{type}/set_attributes"), post_body
        return response unless response.ok?
        response.data
      end
    end
  end
end
