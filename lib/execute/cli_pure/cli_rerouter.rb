module DTK
  class CLIRerouter

    ROUTER_DATA = {
      :service_module => [
          { :regex => /service-module (?<service_module_id>[\w:\-]+) (?<method_name>stage) (?<assembly_id>[\w:\-]+) (?<instance_name>[\w:\-\.\:]+)/, :entity => 'assembly' },
          { :regex => /service-module (?<service_module_id>[\w:\-]+) (?<method_name>deploy) (?<assembly_id>[\w:\-]+) (?<instance_name>[\w:\-\.\:]+)/ }
        ],
      :service        => [
          { :regex => /service (?<service_id>[\w:\-]+) (?<method_name>set-attribute) (?<name>[\w:\-\.\:]+) (?<value>[\w:\-\.\:]+)/ },
          { :regex => /service (?<service_id>[\w:\-]+) (?<method_name>converge)/ },
          { :regex => /service (?<method_name>delete-and-destroy) (?<instance_name>[\w:\-]+)/ }
        ]
    }

    def initialize(entity_name, args)
      @cli_string  = CLIRerouter.formulate_command_string(entity_name, args)
      @entity_name = CLIRerouter.norm(entity_name)

      ROUTER_DATA[@entity_name].each do |defintion|
        if match = @cli_string.match(defintion[:regex])
          @method_name = CLIRerouter.norm(match[:method_name])

          # sometimes we need to override entity
          @entity_name = defintion[:entity] if defintion[:entity]

          # we need to filter out IDs
          @entity_ids  = match.names.collect { |k| k.to_s.end_with?('_id') ? { k => match[k] } : nil }.compact

          if @entity_ids.empty?
            # match 1 is method name, there is no id
            @args = match[2, match.size]
          else
            # match 1, 2 are id and method name rest are args
            @args = match[@entity_ids.size + 2, match.size]
          end

          break
        end
      end

      @conn = ::DTK::Client::Session.get_connection()
      exit if validate_connection(@conn)
    end

    def run
      new_context_params = DTK::Shell::ContextParams.new

      @entity_ids.each do |value_hash|
        key    = value_hash.keys.first
        value  = value_hash.values.first
        entity_name_of_param = key.gsub('_id', '')
        new_context_params.add_context_name_to_params(entity_name_of_param, entity_name_of_param, value)
      end

      new_context_params.method_arguments = @args
      new_context_params.pure_cli_mode    = true
      DTK::Client::ContextRouter.routeTask(@entity_name, @method_name, new_context_params, @conn)
    end

    def self.is_candidate?(entity_name, args)
      cli = formulate_command_string(entity_name, args)
      if definitions = ROUTER_DATA[norm(entity_name)]
        is_match = definitions.find { |d| cli.match(d[:regex]) }

        return true if is_match
      end

      return false
    end

  private

    def self.norm(string_value)
      return string_value ? string_value.gsub('-','_').to_sym : nil
    end

    def self.formulate_command_string(entity_name, args)
      "#{entity_name} #{args.join(' ')}".strip()
    end
  end
end