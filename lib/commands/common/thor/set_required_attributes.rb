#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
module DTK::Client
  module SetRequiredParamsMixin
    def set_required_attributes_aux(id,type,subtype=nil)
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
        param_bindings = DTK::Shell::InteractiveWizard.resolve_missing_params(missing_params)
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