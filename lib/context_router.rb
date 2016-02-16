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
module DTK
  module Client

    #
    # This class is used to reroute commands/tasks (Method invocations) from one context (Class) to another
    #
    class ContextRouter

      extend DTK::Client::Auxiliary

      # This method invokes target context task
      def self.routeTask(target_context, target_method, target_context_params, conn)
        target_context = target_context.to_s
        target_method  = target_method.to_s

        # Initing required params and invoking target_context.target_method
        load_command(target_context)
        target_context_class = DTK::Client.const_get "#{cap_form(target_context)}"

        ret = target_context_class.execute_from_cli(conn, target_method, target_context_params, [], false)
        ret.kind_of?(Response::NoOp) ? Response::Ok.new() : ret
      end

    end

  end
end
