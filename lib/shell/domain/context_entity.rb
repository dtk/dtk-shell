module DTK::Shell
  class ContextEntity
    attr_accessor   :entity
    attr_accessor   :name
    attr_accessor   :identifier
    attr_accessor   :alt_identifier

    SHELL_SEPARATOR = '/'

    def self.create_context(context_name, entity_name, context_value=nil, type_id=:id)
      # DEBUG SNIPPET >>> REMOVE <<<
      # require 'ap'
      # ap "CREATE CONTEXT"
      # ap context_name
      # ap entity_name
      # ap context_value
      # ap type_id
      # ap ">.............................................<"
      if context_value
        if :id.eql?(type_id)
          return ContextEntity.create_identifier(context_name, entity_name, context_value)
        else
          return ContextEntity.create_name_identifier(context_name, entity_name, context_value)
        end
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
      @name.gsub(::DTK::Client::CommandBaseThor::ALT_IDENTIFIER_SEPARATOR, SHELL_SEPARATOR)
    end

    private

    def self.create_command(name, entity_name)
      instance = ContextEntity.new
      instance.name   = name
      instance.entity = entity_name.to_sym
      return instance
    end

    def self.create_name_identifier(name, entity_name, value)
      instance            = self.create_command(name,entity_name)
      instance.name           = value
      instance.identifier     = value
      instance.alt_identifier = value
      return instance
    end

    def self.create_identifier(name, entity_name, value)
      instance                = self.create_command(name,entity_name)
      instance.identifier     = value
      alt_identifier_name = name.to_s.split(::DTK::Client::CommandBaseThor::ALT_IDENTIFIER_SEPARATOR)
      instance.alt_identifier = alt_identifier_name.size > 1 ? alt_identifier_name.first : nil
      return instance
    end
  end
end