dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/push_clone_changes')
module DTK::Client
  module EditMixin
    include CloneMixin
    include PushCloneChangesMixin

    ##
    #
    # module_type: will be one of 
    # :component_module
    # :service_module 
    def edit_aux(module_type,module_id,module_name,version,opts={})
      module_location  = OsUtil.module_location(module_type,module_name,version,opts)

      # check if there is repository cloned 
      unless File.directory?(module_location)
        if Console.confirmation_prompt("Edit not possible, module '#{module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          internal_trigger = true
          omit_output = true
          response = clone_aux(module_type,module_id,version,internal_trigger,omit_output,opts)
          # if error return
          unless response.ok?
            return response
          end
        else
          # user choose not to clone needed module
          return
        end
      end

      # here we should have desired module cloned
      Console.unix_shell(module_location, module_id, module_type, version)
      grit_adapter = ::DTK::Common::GritAdapter::FileAccess.new(module_location)

      if grit_adapter.changed?
        grit_adapter.print_status

        # check to see if auto commit flag
        auto_commit  = ::DTK::Configuration.get(:auto_commit_changes)
        confirmed_ok = false

        # if there is no auto commit ask for confirmation
        unless auto_commit
          confirmed_ok = Console.confirmation_prompt("Would you like to commit and push following changes (keep in mind this will commit ALL above changes)?") 
        end

        if (auto_commit || confirmed_ok)
          if auto_commit 
            puts "[NOTICE] You are using auto-commit option, all changes you have made will be commited."
          end
          commit_msg = user_input("Commit message")
          internal_trigger=true
          reparse_aux(module_location)
          response = push_clone_changes_aux(module_type,module_id,version,commit_msg,internal_trigger,opts)
          # if error return
          return response unless response.ok?
        end

        #TODO: temporary took out; wil put back in        
        #puts "DTK SHELL TIP: Adding the client configuration parameter <config param name>=true will have the client automatically commit each time you exit edit mode" unless auto_commit
      else
        puts "No changes to repository"
      end
      return
    end
  end
end
