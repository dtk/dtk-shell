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
  module Commands
    module Common
      class Base
        def initialize(command_base,context_params)
          @command_base = command_base
          @context_params = context_params
        end
       private
        def retrieve_arguments(mapping)
          @context_params.retrieve_arguments(mapping,@command_base.method_argument_names())
        end

        def retrieve_option_hash(option_list)
          ret = Hash.new
          option_values = @context_params.retrieve_thor_options(option_list,@command_base.options)
          option_values.each_with_index do |val,i|
            unless val.nil?
              key = option_list[i].to_s.gsub(/\!$/,'').to_sym
              ret.merge!(key => val)
            end
          end
          ret
        end

        def post(url_path,body=nil)
          @command_base.post(@command_base.rest_url(url_path),body)
        end
      end
    end
  end
end
