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
  class Violation
    module Fix
      class Result
        Types = [:ok, :error, :skip_current, :error]

        def initialize(type)
          @type = type
        end

        def self.method_missing?(method, *args)
          is_type?(method) ? new(type) : super
        end
        def self.respond_to?(method)
          !!is_type?(method) 
        end

        def method_missing?(method, *args)
          if type = is_type_with_question_mark?(method)
            type == @type
          else
            super
          end
        end
        def respond_to?(method)
          !!is_type_with_question_mark?(method)
        end
        
        private

        def self.is_type?(method)
          Types.include?(method) ? method : nil
        end

        def is_type_with_question_mark?(method)
          if method.to_s =~ /(^.+)[$]$/
            type = $1.to_sym
            self.class.is_type?(type)
          end
        end
      end
    end
  end
end

