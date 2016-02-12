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
    class ViewProcHashPrettyPrint < ViewProcessor
      include ::DTK::Client::Auxiliary
      def render(hash)
        object_def = get_top_def()
        raise_error() unless object_def
        render_object_def(hash,object_def)
      end
     private
      attr_reader :meta
      def initialize(type,command_class,data_type_index=nil)
        super
        @meta = get_meta(type,command_class,data_type_index)
      end

      def failback_meta(ordered_cols)
        {
          :top_type => :top,
          :defs => {:top_def => ordered_cols}
        }
      end

      def get_top_def()
        raise_error("No Top def") unless top_object_type = meta[:top_type]
        get_object_def(top_object_type)
      end

      def get_object_def(object_type)
        if defs = meta[:defs] and object_type
          {object_type => defs["#{object_type}_def".to_sym]}
        end
      end
      def raise_error(msg=nil)
        msg ||= "No hash pretty print view defined"
        raise Error.new(msg)
      end
      def render_object_def(object,object_def,opts={})
        #TODO: stub making it only first level
        return object unless object.kind_of?(Hash)
        hash = object
        ret = ViewPrettyPrintHash.new(object_def.keys.first)

        object_def.values.first.each do |item|
          if item.kind_of?(Hash)
            render_object_def__hash_def!(ret,hash,item)    
          else
            key = item.to_s
            target_key = replace_with_key_alias?(key) 
            #TODO: may want to conditionally include nil values
            ret[target_key] = hash[key] if hash[key]
          end
        end
        #catch all for keys not defined
        unless opts[:only_explicit_cols]
          (hash.keys.map{|k|replace_with_key_alias?(k)} - ret.keys).each do |key|
            ret[key] = hash[key] if hash[key]
          end
        end
        return ret
      end
      def replace_with_key_alias?(key)
        #TODO: fix
        return key
        if ret = GlobalKeyAliases[key.to_sym] then ret.to_s 
        else key
        end
      end
      GlobalKeyAliases = {
        :library_library_id => :library_id,
        :datacenter_datacenter_id => :target_id
      }

      def render_object_def__hash_def!(ret,hash,hash_def_item)
        key = hash_def_item.keys.first.to_s
        return unless input = hash[key]
        hash_def_info = hash_def_item.values.first
        nested_object_def = get_object_def(hash_def_info[:type])
        raise_error("object def of type (#{hash_def_info[:type]||""}) does not exist") unless nested_object_def

        opts = Hash.new
        if hash_def_info[:only_explicit_cols]
          opts.merge!(:only_explicit_cols => true)
        end
        if hash_def_info[:is_array]
          raise_error("hash subpart should be an array") unless input.kind_of?(Array)
          ret[key] = input.map{|el|render_object_def(el,nested_object_def,opts)}
        else
          ret[key] = render_object_def(input,nested_object_def,opts)
        end
      end
    end
    class ViewPrettyPrintHash < Common::PrettyPrintHash
      def initialize(object_type=nil)
        super()
        @object_type = object_type
      end
      attr_accessor :object_type
      def slice(*keys)
        ret = super
        ret.object_type = object_type
        ret
      end
    end
  end
end