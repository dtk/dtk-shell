##
# This is temporary workaround to faciliate concept we are introducing
#
# Entity / Double Entity Identifier
#

module DTK
  module Shell
    class ShadowEntity

      def self.resolve(context_entity)
        entity, shadow_entity = context_entity.entity, context_entity.shadow_entity

        return nil if shadow_entity.nil? || entity.nil?
        entity_mapping = @shadow_mapping.fetch(entity.to_sym)

        return entity_mapping ? entity_mapping.fetch(shadow_entity.to_sym) : nil
      end

      def self.resolve_tasks(context_entity)
        entity, shadow_entity = context_entity.entity, context_entity.shadow_entity
        entity_mapping = @shadow_mapping.fetch(entity.to_sym)

        raise DTK::Client::DtkError, "You are missing mapping for shadow entity #{entity} / #{shadow_entity} you need to specify it" if entity_mapping.nil?

        shadow_entity_mapping = entity_mapping.fetch(shadow_entity.to_sym)

        # return just task names
        return shadow_entity_mapping.collect { |se_map| se_map.first.split(' ').first }
      end

    private

      @shadow_mapping = {
        :node => {
          :node_group => [
            ["add-component COMPONENT", "# Add a component to the node."],
            ["list-attributes", "# List attributes associated with service's node."],
            ["list-components", "# List components associated with service's node."],
            ["delete-component COMPONENT-NAME [-y]", "# Delete component from service's node"],
            ["set-attribute ATTRIBUTE-NAME [VALUE] [-u]", "# (Un)Set attribute value. The option -u will unset the attribute's value."]
          ],
          :node_group_node => [
            ["info", "# Return info about node instance belonging to given workspace."],
            ["start", "# Start node instance."],
            ["stop", "# Stop node instance."],
            ["ssh REMOTE-USER [-i PATH-TO-PEM]", "# SSH into node, optional parameters are path to identity file."]
          ]
        }
      }

      if ::DTK::Configuration.get(:development_mode)
        @shadow_mapping[:node][:node_group_node] << ["test-action-agent BASH-COMMAND-LINE", "# Run bash command on test action agent"]
      end


    end
  end
end
