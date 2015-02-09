module DTK::Shell
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

    def push_new_context(context_name, entity_name, context_value=nil, shadow_entity=nil)
      @context_list << ContextEntity.create_context(context_name, entity_name, context_value, :id, shadow_entity)
    end

    def push_new_name_context(context_name, entity_name, context_value=nil)
      @context_list << ContextEntity.create_context(context_name, entity_name, context_value, :name)
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
      path = Context.enchance_path_with_alias(path, @context_list)

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

    def is_base_context?
      @context_list.size == 1
    end

    def is_root_context?
      @context_list.size == 0
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

    def first_context()
      return @context_list.empty? ? nil : @context_list.first
    end

    def last_context()
      return @context_list.empty? ? nil : @context_list.last
    end

    def last_context_is_shadow_entity?
      return false if @context_list.empty?
      !!last_context().shadow_entity
    end
  end
end