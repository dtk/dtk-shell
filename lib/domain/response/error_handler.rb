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
module DTK; module Client
  class Response
    module ErrorHandlerMixin
      # opts can be
      #  :default_error_if_nil - Boolean
      def error_info?(opts={})
        ErrorHandler.error_info?(self,opts)
      end
    end

    module ErrorHandler
      SpecificErrorCodes = [:unauthorized,:session_timeout,:broken,:forbidden,:timeout,:connection_refused,:resource_not_found,:pg_error]
      DefaultErrorCode = :error
      DefaultErrorMsg = 'Internal DTK Client error, please try again'

      Info = Struct.new(:msg,:code,:backtrace)
      def self.error_info?(response, opts={})
        unless errors = response["errors"]
          return (opts[:default_error_if_nil] && error_info_default())
        end

        error_msg       = ""
        error_internal  = nil
        error_backtrace = nil
        error_code      = nil
        error_on_server = nil

        #TODO:  below just 'captures' first error
        errors.each do |err|
          error_msg       +=  err["message"] unless err["message"].nil?
          error_msg       +=  err["error"]   unless err["error"].nil?
          error_msg       +=  OsUtil.remove_html_tags(err["original_exception"]) unless err["original_exception"].nil?
          error_on_server = true unless err["on_client"]
          error_code      = err["code"]||(err["errors"] && err["errors"].first["code"])
          error_internal  ||= (err["internal"] or error_code == "not_found") #"not_found" code is at Ramaze level; so error_internal not set
          error_backtrace ||= err["backtrace"]
        end

        # in case we could not parse error lets log error info
        if error_msg.empty?
          DtkLogger.instance.error("Error info could not be extracted from following response: " + response.to_s)
        end

        # normalize it for display
        error_msg = error_msg.empty? ? DefaultErrorMsg : "#{error_msg}"

        unless error_code and SpecificErrorCodes.include?(error_code)
          error_code =
            if error_internal
              error_on_server ? :server_error : :client_error
            else
              DefaultErrorCode
            end
        end

        error_code = error_code.to_sym
        Info.new(error_msg,error_code,error_backtrace)
      end

      def self.error_info_default()
        Info.new(DefaultErrorMsg,DefaultErrorCode,nil)
      end

    end
  end
end; end
