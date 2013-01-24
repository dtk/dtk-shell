module DTK
  module Shell

    class ContextParams

      def initialize
        @hashed_args = {}
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

      # TODO: Remove accessor for debug purpose only
      attr_accessor :context_list

      def initialize
        @context_list = []
      end

      def push_new_context(context_name, entity_name, context_value=nil)
        @context_list << ContextEntity.create_context(context_name, entity_name, context_value)
      end

      def pop_context(n)
        return @context_list.pop(n)
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