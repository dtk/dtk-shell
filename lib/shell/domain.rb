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

      def retrieve_arguments(mapping, method_info = nil)
        results = []
        errors  = []

        mapping.each do |key|

          required = key.to_s.match(/.+!$/)

          element = nil
          matched = key.to_s.match(/option_([0-9]+)/)
          if matched
            id = matched[1].to_i - 1
            element = @method_arguments[id]

            if method_info
              unless element
                errors << method_info[id] if required
              end
            end

          else
            # More complex split regex for extracting entitiy name from mapping due to complex context names
            # i.e. assembly-template will have assembly_template_id mapping
            split_info = key.to_s.split(/_([a-z]+!?$)/)
            entity_name = split_info[0].gsub(/_/,'-')  # makes sure we are using entity names with '_'
            id_type     = split_info[1].gsub(/!/,'')   # for required elements we remove '!' required marker
            context_identifier = @current_context.find_identifier(entity_name)
            if context_identifier
              element = context_identifier.get_identifier(id_type)
            else
              element = nil
            end

            unless element
              errors << "#{entity_name.upcase} ID/NAME" if required
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
    end

    class ContextEntity
      attr_accessor   :entity
      attr_accessor   :name
      attr_accessor   :identifier

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

      def is_command?
        return @identifier.nil?
      end

      def get_identifier(type)
        return (type == 'id' ? self.identifier : self.name)
      end

      private

      def self.create_command(name, entity_name)
        instance = ContextEntity.new
        instance.name   = name
        instance.entity = entity_name.to_sym
        return instance
      end

      def self.create_identifier(name, entity_name, value)
        instance            = self.create_command(name,entity_name)
        instance.identifier = value
        return instance
      end
    end

    class ActiveContext

      # special case when we are not able to provide valid identifier but we are 
      # using it as such
      NO_IDENTIFIER_PROVIDED = -1


      # list of cases where we want entity to behave differently 
      SHADOWING_ENTITIES = { :workspace => :assembly }

      # TODO: Remove accessor for debug purpose only
      attr_accessor :context_list


      def self.is_shadowed_entity?(entity_name)
        !!SHADOWING_ENTITIES[(entity_name||"NONE_FOUND").to_sym]
      end

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
        @context_list.collect { |e| e.name }
      end

      # returns list of entities that have identifier
      def commands_with_identifiers()
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
        return current_identifier? ? "#{identifier}_wid".to_sym : identifier.to_sym
      end

      def full_path()
        return "/#{name_list.join('/')}"
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

      # includes shadowed entities in their search
      def first_command_name_with_shadow()
        @context_list.each do |e|
          if e.is_command?
            shadowed_entity = SHADOWING_ENTITIES[e.name.to_sym]

            return shadowed_entity ? shadowed_entity.to_s : e.name
          end
        end

        return nil
      end

      def first_command_name()
        @context_list.each do |e|
          return e.name if e.is_command?
        end

        return nil
      end

      def is_shadowed_entity?
        first_command = first_command_name()
        !!SHADOWING_ENTITIES[(first_command||"NONE_FOUND").to_sym]
      end

      def is_there_indetifier_for_first_context_or_shadowed?
        is_there_identifier_for_first_context? || is_shadowed_entity?
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

      def last_context()
        return @context_list.empty? ? nil : @context_list.last
      end

    end

    class CachedTasks < Hash
    end

    class OverrideTasks < Hash

      attr_accessor :completed_tasks


      # help_item (Thor printable task), structure:
      # [0] => task defintion
      # [1] => task description
      # [2] => task name

      # overriden_task (DTK override task), structure:
      # [0] => task name
      # [1] => task defintion
      # [2] => task description


      def initialize(hash=nil)
        super
        @completed_tasks = []
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
        @completed_tasks.include?(child_name)
      end

      def add_to_completed(child_name)
        @completed_tasks << child_name
      end
    end
    
  end
end