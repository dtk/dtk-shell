require File.expand_path('commands/thor/dtk', File.dirname(__FILE__))

module DTK
  module Client
    module Advanced_Context
      ASSEMBLY_LEVELS       = ['assembly','node','component-template','attribute']
      @@advanced_context_response = {}

      def valid_command_id_pairs(multiple_commands)
        commands, ids    = split_commands_ids(multiple_commands)
        index            = ASSEMBLY_LEVELS.include?(commands.first) ? ASSEMBLY_LEVELS.index(commands.first) : 0

        for i in 0..commands.size-1
          return false unless commands[i] == ASSEMBLY_LEVELS[i+index]
        end
        
        return true
      end

      def get_commands_ids(multiple_commands)
        command_id_pairs = []
        commands, ids    = split_commands_ids(multiple_commands)
        index            = ASSEMBLY_LEVELS.include?(commands.first) ? ASSEMBLY_LEVELS.index(commands.first) : 0

        for i in 0..commands.size-1
          raise DTK::Shell::Error, "#{commands[i]} doesn not belong to Assembly level." unless commands[i] == ASSEMBLY_LEVELS[i+index]
          # store command,id pairs e.g. 'node' => 'bootstrap-node-2'
          command_id_pairs << {commands[i] => ids[i]}
        end

        return command_id_pairs
      end

      def split_commands_ids(multiple_commands)
        commands = []
        ids      = []

        for i in 0..multiple_commands.size-1
          if (i%2 == 0)
            commands << multiple_commands[i]
          else
            ids << multiple_commands[i]
          end
        end
        
        return commands, ids
      end

      def self.get_advanced_cached_response(clazz, url, subtype=nil)
        response = post rest_url(url), subtype
        
        # we do not want to catch is if it is not valid
        if response.nil? || response.empty?
          DtkLogger.instance.debug("Response was nil or empty for that reason we did not cache it.")
          return response
        end

        @@advanced_context_response.store(clazz, {:response => response, :ts => current_ts})
    
        return @@advanced_context_response[clazz][:response]
      end

      def self.advanced_valid_id?(value, conn)
        @conn    = conn if @conn.nil?
        clazz, endpoint, subtype = whoami()

        response = get_advanced_cached_response(clazz, endpoint, subtype) if @@advanced_context_response[clazz].nil?

        unless (response.nil? || response.empty? || response['data'].nil?)
          response['data'].each do |element|
            return true if (element['id'].to_s==value || element['display_name'].to_s==value)
          end
          return false
        end

        DtkLogger.instance.warn("[WARNING] We were not able to check cached context, possible errors may occur.")
        return true
      end

      def self.advanced_get_identifiers(conn)
        @conn    = conn if @conn.nil?
        clazz, endpoint, subtype = whoami()

        response = get_cached_response(clazz, endpoint, subtype) if @@advanced_context_response[clazz].nil?

        unless (response.nil? || response.empty?)
          unless response['data'].nil?
            identifiers = []
            response['data'].each do |element|
               identifiers << element['display_name']
            end
            return identifiers
          end          
        end

        DtkLogger.instance.warn("[WARNING] We were not able to check cached context, possible errors may occur.")
        return []
      end
    
    end
  end
end
