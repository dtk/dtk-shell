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
#TODO: test for assembly list/display; want to make assembly specfic stuff datadriven
dtk_require 'simple_list'
module DTK
  module Client
    class ViewProcAugmentedSimpleList < ViewProcSimpleList
     private
      def initialize(type,command_class,data_type_index=nil)
        super
        @meta = get_meta(type,command_class)
      end
      def failback_meta(ordered_cols)
        nil
      end
      def simple_value_render(ordered_hash,ident_info)
        augmented_def?(ordered_hash,ident_info) || super
      end
      def augmented_def?(ordered_hash,ident_info)
        return nil unless @meta
        if aug_def =  @meta["#{ordered_hash.object_type}_def".to_sym]
          ident_str = ident_str(ident_info[:ident]||0)
          vals = aug_def[:keys].map{|k|ordered_hash[k.to_s]}
          "#{ident_str}#{aug_def[:fn].call(*vals)}\n"
        end
      end
    end
  end
end
