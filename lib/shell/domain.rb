module DTK
  module Shell

    class ContextParams

      attr_accessor :current_context
      attr_accessor :method_arguments

      def initialize(override_method_arguments = [])
        @current_context  = ActiveContext.new
        @method_arguments = override_method_arguments
        @thor_options          = nil
      end

      def add_context_to_params(context_name, entity_name, context_value = nil)
        @current_context.push_new_context(context_name, entity_name, context_value)
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
          raise DTK::Client::DtkValidationError, "Missing required option#{errors.size > 1 ? 's' : ''}: #{errors.join(', ')}"
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
                  if alternative_key.to_s.include?(context_name.downcase!)
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
          raise DTK::Client::DtkValidationError, "Missing required argument#{errors.size > 1 ? 's' : ''}: #{errors.join(', ')}"
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

      def split_info(key_mapping)
        key_mapping.to_s.split(/_([a-z]+!?$)/)
      end

    end

    class ContextEntity
      attr_accessor   :entity
      attr_accessor   :name
      attr_accessor   :identifier
      attr_accessor   :alt_identifier

      SHELL_SEPARATOR = '/'

      def self.create_context(context_name, entity_name, context_value=nil)
        if context_value
          return ContextEntity.create_identifier(context_name, entity_name, context_value)
        else
          return ContextEntity.create_command(context_name, entity_name)
        end
      end

      def is_identifier?
        return !@identifier.nil?
      end

      def is_alt_identifier?
        return !@alt_identifier.nil?
      end

      def is_command?
        return @identifier.nil?
      end

      def get_identifier(type)
        return (type == 'id' ? self.identifier : self.name)
      end

      def transform_alt_identifier_name()
        @name.gsub(Client::CommandBaseThor::ALT_IDENTIFIER_SEPARATOR, SHELL_SEPARATOR)
      end

      private

      def self.create_command(name, entity_name)
        instance = ContextEntity.new
        instance.name   = name
        instance.entity = entity_name.to_sym
        return instance
      end

      def self.create_identifier(name, entity_name, value)
        instance                = self.create_command(name,entity_name)
        instance.identifier     = value
        alt_identifier_name = name.to_s.split(Client::CommandBaseThor::ALT_IDENTIFIER_SEPARATOR)
        instance.alt_identifier = alt_identifier_name.size > 1 ? alt_identifier_name.first : nil
        return instance
      end
    end

    class ActiveContext

      # special case when we are not able to provide valid identifier but we are 
      # using it as such
      NO_IDENTIFIER_PROVIDED = -1

      # TODO: Remove accessor for debug purpose only
      attr_accessor :context_list

      def clone_me()
        inst = ActiveContext.new
        inst.context_list = @context_list.clone
        return inst
      end

      def initialize
        @context_list = []
      end

      def push_new_context(context_name, entity_name, context_value=nil)
        @context_list << ContextEntity.create_context(context_name, entity_name, context_value)
      end

      def pop_context(n)
        return @context_list.pop(n)
      end

      def find_identifier(entity_name)
        results = @context_list.select { |e| (e.is_identifier? && (e.entity == entity_name.to_sym))}
        return results.first
      end

      def find_command(entity_name)
        results = @context_list.select { |e| (e.is_command? && (e.entity == entity_name.to_sym))}
        return results.first
      end

      def name_list()
        @context_list.collect { |e|  e.is_alt_identifier? ? e.transform_alt_identifier_name : e.name }
      end

      def name_list_simple()
        @context_list.collect { |e|  e.name }
      end


      # returns list of entities that have identifier
      def commands_that_have_identifiers()
        filtered_entities = @context_list.select { |e| e.is_identifier? }
        return filtered_entities.collect { |e| e.entity.to_s }
      end

      def command_list()
        filtered_entities = @context_list.select { |e| e.is_command? }
        return filtered_entities.collect { |e| e.entity.to_s }
      end

      # returns id to be used to retrive task list form the cache based on 
      # current active context
      def get_task_cache_id()
        identifier = command_list().join('_')
        return 'dtk' if identifier.empty?
        if current_alt_identifier?
          return "#{identifier}_#{current_alt_identifier_name()}".to_sym()
        end

        return current_identifier? ? "#{identifier}_wid".to_sym : identifier.to_sym
      end

      def full_path()
        path = name_list().join('/')
        path = Context.enchance_path_with_alias(path)

        return "/#{path}"
      end

      def clear()
        @context_list.clear
      end

      def empty?()
        return @context_list.empty?
      end

      def is_n_context?
        @context_list.size > 2
      end

      def current_command?
        return @context_list.empty? ? true : @context_list.last.is_command?
      end

      def current_identifier?
        return @context_list.empty? ? false : @context_list.last.is_identifier?
      end

      def current_alt_identifier?
        return @context_list.empty? ? false : @context_list.last.is_alt_identifier?
      end

      def current_alt_identifier_name
        @context_list.last.alt_identifier
      end

      def first_command_name()
        @context_list.each do |e|
          return e.name if e.is_command?
        end

        return nil
      end

      def is_there_identifier_for_first_context?
        @context_list.each { |e| return true if e.is_identifier? }
        return false
      end

      def last_command_name()
        @context_list.reverse.each do |e|
          return e.name if e.is_command?
        end

        return nil
      end

      def last_context_entity_name()
        return @context_list.empty? ? nil : @context_list.last.entity
      end

      def last_context_name()
        return @context_list.empty? ? nil : @context_list.last.name
      end

      def first_context_name()
        return @context_list.empty? ? nil : @context_list.first.name
      end

      def last_context()
        return @context_list.empty? ? nil : @context_list.last
      end

    end

    class CachedTasks < Hash
    end

    class OverrideTasks < Hash

      attr_accessor :completed_tasks
      attr_accessor :always_load_list


      # help_item (Thor printable task), structure:
      # [0] => task defintion
      # [1] => task description
      # [2] => task name

      # overriden_task (DTK override task), structure:
      # [0] => task name
      # [1] => task defintion
      # [2] => task description

      # using 'always load listed' to skip adding task to completed tasks e.g load utils for workspace and workspace_node
      def initialize(hash=nil, always_load_listed=[])
        super(hash)
        @completed_tasks = []
        @always_load_list = always_load_listed
        self.merge!(hash)
      end

      # returns true if there are overrides for tasks on first two levels.
      def are_there_self_override_tasks?
        return (self[:all][:self] || self[:command_only][:self] || self[:identifier_only][:self])
      end

      def check_help_item(help_item, is_command)
        command_tasks, identifier_tasks = get_all_tasks(:self)
        found = []

        if is_command
          found = command_tasks.select { |o_task| o_task[0].eql?(help_item[2]) }
        else
          found = identifier_tasks.select { |o_task| o_task[0].eql?(help_item[2]) }
        end

        # if we find self overriden task we remove it
        # [found.first[1],found.first[2],found.first[0]] => we convert from o_task structure to thor help structure
        return found.empty? ? help_item : [found.first[1],found.first[2],found.first[0]]
      end

      # returns 2 arrays one for commands and next one for identifiers
      def get_all_tasks(child_name)
        command_o_tasks, identifier_o_tasks = [], []           
        command_o_tasks    = (self[:all][child_name]||[]) + (self[:command_only][child_name]||[])
        identifier_o_tasks = (self[:all][child_name]||[]) + (self[:identifier_only][child_name]||[])
        return command_o_tasks, identifier_o_tasks
      end

      def is_completed?(child_name)
        # do not add task to completed if explicitly said to always load that task
        return false if @always_load_list.include?(child_name)
        @completed_tasks.include?(child_name)
      end

      def add_to_completed(child_name)
        @completed_tasks << child_name
      end
    end
    
  end
end
