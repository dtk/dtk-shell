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
class DTK::Client::Execute
  class ExecuteContext
    dtk_require('execute_context/result_store')

    module ClassMixin
      def ExecuteContext(opts={},&block)
        ExecuteContext.new(opts).execute(&block)
      end
    end

    def initialize(opts={})
      @print_results = opts[:print_results]
      @proxy = Proxy.new()
    end

    def execute(&block)
      result, command = instance_eval(&block)
      result
    end

    def method_missing(m, *args, &block)
      result, command = @proxy.send(m, *args, &block)
      if @print_results
        pp(:command => command.input_hash(),:result => result) 
      end
      [result, command]
    end

    # commands in the execute context
    class Proxy
      def initialize()
        @result_store = ResultStore.new()
      end

      def call(object_type__method,params={})
        object_type, method = split_object_type__method(object_type__method)
        api_command = Command::APICall.new(:object_type => object_type, :method => method, :params => params)
        result = nil
        api_command.raw_executable_commands() do |raw_command|
          last_result = @result_store.get_last_result?()
          command = raw_command.translate(params,:last_result => last_result)
          result = CommandProcessor.execute(command)
          @result_store.store(result)
        end
        [result, api_command]
      end
      
      def post_rest_call(path,body={})
        command = Command::RestCall::Post.new(:path => path, :body => body, :last_result => @last_result)
        result = CommandProcessor.execute(command)
        [result, command]
      end

     private 
      # returns [object_type, method]
      def split_object_type__method(str)
        DelimitersObjectTypeMethod.each do |d| 
          if str =~ Regexp.new("(^[^#{d}]+)#{d}([^#{d}]+$)") 
            return [$1,$2]
          end
        end
        raise ErrorUsage.new("Illegal term '#{str}'")
      end
      
      DelimitersObjectTypeMethod = ['\/']
    end

  end
end