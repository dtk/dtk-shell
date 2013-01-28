module DTK
  module Shell

    class ContextParams

      attr_accessor :current_context
      attr_accessor :method_arguments

      def initialize
        @current_context  = ActiveContext.new
        @method_arguments = []
      end

      def add_context_to_params(context_name, entity_name, context_value = nil)
        @current_context.push_new_context(context_name, entity_name, context_value)
      end

      def retrieve_arguments(mapping)
        results = []

        mapping.each do |key|
          element = nil
          matched = key.to_s.match(/option_([0-9]+)/)
          if matched
            id = matched[1].to_i - 1
            element = @method_arguments[id]
          else
            split_info = key.to_s.split('_')
            entity_name = split_info[0]
            id_type     = split_info[1]
            context_identifier = @current_context.find_identifier(entity_name)
            if context_identifier
              element = context_identifier.get_identifier(id_type)
            else
              element = nil
            end
          end

          results << element 
        end

        return ((results.size == 1) ? results.first : results)
      end

      def is_there_identifier?(entity_name)
        return @current_context.find_identifier(entity_name) != nil
      end

      def is_there_command?(entity_name)
        return @current_context.find_command(entity_name) != nil
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
        instance.name   = name.downcase
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
        @context_list.collect { |e| e.name }
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

      def current_command?
        return @context_list.empty? ? true : @context_list.last.is_command?
      end

      def current_identifier?
        return @context_list.empty? ? false : @context_list.last.is_identifier?
      end

      def last_command_name()
        @context_list.reverse.each do |e|
          return e.name if e.is_command?
        end

        return nil
      end

      def last_context_name()
        return @context_list.empty? ? nil : @context_list.last.name
      end

    end
    
  end
end