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
require 'erubis'
module DTK
  module Client
    class ViewProcSimpleList < ViewProcessor
      def render(hash)                  
        pp_adapter = ViewProcessor.get_adapter("hash_pretty_print",@command_class,@data_type_index)
        ordered_hash = pp_adapter.render(hash)
        if ordered_hash.size == 1
          render_simple_assignment(ordered_hash.keys.first,ordered_hash.values.first)
        else
          render_ordered_hash(ordered_hash)
        end
      end
     private
      #TODO Aldin check if assembly or assembly_name
      HIDE_FROM_VIEW = ["assembly"]
      def render_simple_assignment(key,val)
        key + KeyValSeperator + val.to_s + "\n" 
      end
      def render_ordered_hash(ordered_hash,ident_info={},index=1)
        #find next value that is type pretty print hash or array
        beg,nested,rest = find_first_non_scalar(ordered_hash)
        ret = String.new
        unless beg.empty?
          ret = simple_value_render(beg,ident_info.merge(:index => index))
        end
        unless nested.empty?
          ident_info_nested = {
            :ident => (ident_info[:ident]||0) +IdentAdd,
            :nested_key => nested.keys.first
          }
          ident_info_nested[:ident] += IdentAdd
          ret << "#{ident_str(ident_info_nested[:ident])}#{nested.keys.first.upcase}\n"
          vals = nested.values.first
          vals = [vals] unless vals.kind_of?(Array)
          vals.each_with_index{|val,i|ret << render_ordered_hash(val,ident_info_nested,i+1)}
        end
        unless rest.empty?
          rest = hide_from_view(rest)
          ret << render_ordered_hash(rest,ident_info.merge(:include_first_key => true))
        end
        ret
      end

      def hide_from_view(ordered_hash)
        ordered_hash.each do |k,v|
          ordered_hash.delete_if{|k,v| HIDE_FROM_VIEW.include?(k)}
        end
        return ordered_hash
      end

      # Exclude  = ["op_status","assembly_template"]
      IdentAdd = 2
      def find_first_non_scalar(ordered_hash)
        found = nil
        keys = ordered_hash.keys
        keys.each_with_index do |k,i|
          val = ordered_hash[k]
          if val.kind_of?(ViewPrettyPrintHash) or 
              (val.kind_of?(Array) and val.size > 0 and val.first.kind_of?(ViewPrettyPrintHash))
            found = i
            break
          end
        end
        if found.nil?
          empty_ordered_hash = ordered_hash.class.new
          [ordered_hash,empty_ordered_hash,empty_ordered_hash]
        else
          [keys[0,found],keys[found,1],keys[found+1,keys.size-1]].map{|key_array|ordered_hash.slice(*key_array)}
        end
      end
      def is_scalar_type?(x)
        [String,Fixnum,Bignum].find{|t|x.kind_of?(t)}
      end

      def convert_to_string_form(val)
        if val.kind_of?(Array)
          "[#{val.map{|el|convert_to_string_form(el)}.join(",")}]"
        elsif is_scalar_type?(val)
          val.to_s
        else #catchall
          pp_form val
        end
      end
      def pp_form(obj)
        ret = String.new
        PP.pp obj, ret
        ret.chomp!
      end

      def ident_str(n)
        Array.new(n, " ").join
      end

      #process elements that are not scalars
      def proc_ordered_hash(ordered_hash)
        updated_els = Hash.new
        ordered_hash.each do |k,v|
          unless is_scalar_type?(v)
            updated_els[k] = convert_to_string_form(v)
          end
        end
        
        ordered_hash.merge(updated_els)
      end

      def simple_value_render(ordered_hash,ident_info)
           
        proc_ordered_hash = proc_ordered_hash(ordered_hash)

        ident = ident_info[:ident]||0
        first_prefix = (ident_info[:include_first_key] ?
          (ident_str(ident+IdentAdd) + ordered_hash.keys.first + KeyValSeperator) : ident_str(ident))
        first_suffix = ((ident_info[:include_first_key] or not ordered_hash.object_type) ? "" : " (#{ordered_hash.object_type})")
        rest_prefix = ident_str(ident+IdentAdd)

        template_bindings = {
          :ordered_hash => proc_ordered_hash,
          :first_prefix => first_prefix,
          :first_suffix => first_suffix,
          :rest_prefix => rest_prefix,
          :sep => KeyValSeperator
        }

        SimpleListTemplate.result(template_bindings)
      end
      KeyValSeperator = ": "
SimpleListTemplate = Erubis::Eruby.new <<eos
<% keys = ordered_hash.keys %>
<% first = keys.shift  %>
<%= rest_prefix %><%= first_prefix.strip %><%= ordered_hash[first] %>
<% keys.each do |k| %>
<%= rest_prefix %><%= k %><%= sep  %><%= ordered_hash[k] %>
<% end %>
eos

    end
  end
end
