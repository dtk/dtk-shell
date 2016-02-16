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
module DTK::Shell
  class ContextParams

    attr_accessor :current_context
    attr_accessor :method_arguments
    attr_accessor :pure_cli_mode

    def initialize(override_method_arguments = [])
      @current_context  = ActiveContext.new
      @method_arguments = override_method_arguments
      @thor_options     = Hash.new
      @pure_cli_mode    = false

      @method_arguments
    end

    def add_context_to_params(context_name, entity_name, context_value = nil)
      @current_context.push_new_context(context_name, stand_name(entity_name), context_value)
    end

    def add_context_name_to_params(context_name, entity_name, context_value = nil)
      @current_context.push_new_name_context(context_name, stand_name(entity_name), context_value)
    end

    def forward_options(options)
      @thor_options = options
    end

    def get_forwarded_options()
      @thor_options
    end

    def get_forwarded_thor_option(option_key)
      return @thor_options ? @thor_options[option_key] : nil
    end

    def override_method_argument!(key, value)
      id = match_argument_id(key)
      raise DTK::Client::DtkImplementationError, "Wrong identifier used '#{key}', ID not matched!" unless id
      @method_arguments[id] = value
    end

    # can be class methods but no need, since we have this instance available in each method
    def retrieve_thor_options(mapping, options)
      results = []
      errors  = []

      mapping.each do |key|
        required = key.to_s.match(/.+!$/)
        thor_key = key.to_s.gsub('!','')

        results << element = options[thor_key]

        if required && element.nil?
          errors << thor_key
        end
      end

      unless errors.empty?
        raise DTK::Client::DtkValidationError.new("Missing required option#{errors.size > 1 ? 's' : ''}: #{errors.join(', ')}", true)
      end

      return ((results.size == 1) ? results.first : results)
    end

    def retrieve_arguments(mapping, method_info = [])
      results = []
      errors  = []

      # using context_name when have array as key_mapping [:assembly_id, :workspace_id]
      # to determine which context is used
      context_name = method_info.first.split('-').first unless method_info.empty?

      mapping.each do |key_mapping|

        is_array = key_mapping.is_a?(Array)

        selected_key = is_array ? key_mapping.first : key_mapping

        required = selected_key.to_s.match(/.+!$/)

        element = nil
        matched = selected_key.to_s.match(/option_([0-9]+)/)
        if matched
          id = matched[1].to_i - 1
          element = @method_arguments[id]

          # used if last parameter has more than one word
          # e.g. set-attribute attr_name "some value" (thor separates 'some value' as two parameters but we need it as one)
          if(mapping.last.to_s.eql?(key_mapping.to_s))
            new_id = id+1
            while @method_arguments[new_id] do
              element << " #{@method_arguments[new_id]}"
              new_id += 1;
            end
          end

          unless method_info.empty?
            unless element
              errors << method_info[id] if required
            end
          end

        else
          # More complex split regex for extracting entitiy name from mapping due to complex context names
          # i.e. assembly-template will have assembly_template_id mapping
          element = check_context_for_element(selected_key)

          # if we are dealing with array we need to check rest of the keys since it is OR
          # approach if first element not found take second
          if element.nil? && is_array
            key_mapping[1..-1].each do |alternative_key|
              element = check_context_for_element(alternative_key)
              break if element
              if context_name
                if alternative_key.to_s.include?(context_name.downcase)
                  required = alternative_key.to_s.match(/.+!$/)
                  selected_key = alternative_key
                end
              end
            end
          end

          unless element
            errors << "#{entity_name(selected_key).upcase} ID/NAME" if required
          end
        end

        results << element
      end

      unless errors.empty?
        raise DTK::Client::DtkValidationError.new("Missing required argument#{errors.size > 1 ? 's' : ''}: #{errors.join(', ')}", true)
      end

      return ((results.size == 1) ? results.first : results)
    end

    def is_last_command_eql_to?(command_name)
      return @current_context.last_command_name() == command_name.to_s
    end

    def is_there_identifier?(entity_name)
      return @current_context.find_identifier(entity_name) != nil
    end

    def is_there_command?(entity_name)
      return @current_context.find_command(entity_name) != nil
    end
    def current_command?
      return @current_context.current_command?
    end
    def root_command_name
      @current_context.first_command_name
    end
    def last_entity_name
      @current_context.last_context_entity_name
    end
    def shadow_entity_name()
      @current_context.shadow_entity()
    end

    private

    # matches argument id (integer) from used identifier (symbol)
    #
    # Returns: Integer as ID , or nil if not found
    def match_argument_id(identifier)
      matched = identifier.to_s.match(/option_([0-9]+)/)
      (matched ? matched[1].to_i - 1 : nil)
    end

    # based on map key binding e.g. assembly_id, assembly_name we will extrace value
    # from our ActiveContext
    def check_context_for_element(key_mapping)
      split_info  =  split_info(key_mapping)
      entity_name =  entity_name(key_mapping,split_info)
      id_type     = split_info[1].gsub(/!/,'')   # for required elements we remove '!' required marker
      context_identifier = @current_context.find_identifier(entity_name)
      if context_identifier
        return context_identifier.get_identifier(id_type)
      else
        return nil
      end
    end

    def entity_name(key_mapping,split_info=nil)
      split_info ||= split_info(key_mapping)
      split_info[0].gsub(/_/,'-')  # makes sure we are using entity names with '_'
    end

    #
    # Standardize context name since we are in domain treating :component_module as :'component-module'
    # and need to be careful about these changes
    #

    def stand_name(name)
      name.to_s.gsub('_','-').to_sym
    end

    def split_info(key_mapping)
      key_mapping.to_s.split(/_([a-z]+!?$)/)
    end

  end
end
