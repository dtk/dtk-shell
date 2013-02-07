class Thor
  class << self
    # NOTE: Class is loaded automaticly in dtk-shell

    @@shell_context = nil

    def set_context(context)
      @@shell_context = context
    end

    def match_help_item_changes(help_item, entity_name)
      help_item.first.match(/\[?#{entity_name.upcase}.?(NAME\/ID|ID\/NAME|ID|NAME)(\-?PATTERN)?\]?/)
    end

    def replace_if_matched!(help_item, matched)
      # change by reference
      help_item.first.gsub!(matched[0],'') if matched

      return help_item
    end

    def help(shell, subcommand = false)
      list = printable_tasks(true, subcommand)

      Thor::Util.thor_classes_in(self).each do |klass|
        list += klass.printable_tasks(false)
      end

      list.sort!{ |a,b| a[0] <=> b[0] }
  
      # monkey patching here => START
      unless @@shell_context.root?
        command             = @@shell_context.active_context.first_command_name.upcase
        is_there_identifier = @@shell_context.active_context.is_there_identifier_for_first_context?

        filtered_list = []

        # case when we are not on first level and it is not identifier we skip help 
        # since it needs to be empty
        # e.g. assembly/bootstrap1/node> ... HELP IS EMPTY FOR THIS

        unless (@@shell_context.active_context.is_n_context? && @@shell_context.active_context.current_command?)
          list.each do |help_item|
            # matches identifiers for ID/NAME
            matched_data          = help_item.first.match(/^\s\[?#{command}.?(NAME\/ID|ID\/NAME)\]?\s/)
            # if list command matches all bracketed options
            matched_list_options = help_item.first.match(/list (\[.+\])/)
            list_optional_data = matched_list_options.nil? ? nil : matched_list_options[1].split(' ')

            if matched_data.nil?
              # not found and tier 1 we add it to help list
              filtered_list << help_item if @@shell_context.current_command?
            else
              # for help we only care about first context name / identifier
              if !is_there_identifier
                # remove optional data if tier 1 (DTK-211) TODO: Refactor this
                # help_item.first.gsub!(list_optional_data[0],'') unless list_optional_data.nil?
                unless list_optional_data.nil?
                  list_optional_data.each do |item|
                    help_item.first.gsub!(item,'') unless item.include?('--')
                  end
                end

                # if it contains [] it is optional and will be available on both tiers
                if matched_data[0].include?('[')
                  # we remove it, since there is no need to use it
                  help_item.first.gsub!(matched_data[0],' ') unless help_item.nil?
                  filtered_list << help_item  
                end
              else
                # TODO: Better solution for this type of problems (DTK-211)
                unless list_optional_data.nil?
                  for i in 1..list_optional_data.size
                    help_item.first.gsub!(list_optional_data[i].to_s,'') if list_optional_data[i].to_s.include?('--')
                  end
                end

                # found and tier 2 we add it to list and remove ID/NAME part of desc
                help_item.first.gsub!(matched_data[0],'') unless help_item.nil?
                filtered_list << help_item
              end
            end
          end
        end

        commands_with_identifiers =  @@shell_context.active_context.commands_with_identifiers()

        # first one does not count
        if commands_with_identifiers && commands_with_identifiers.size > 1
          # additional filter list for n-context
          n_filter_list = []
          # we do not need first one, since above code takes care of that one
          filtered_list = filtered_list.select do |filtered_help_item|
            #next unless filtered_help_item
            commands_with_identifiers[1..-1].each_with_index do |entity,i|
              matched = match_help_item_changes(filtered_help_item, entity)
              filtered_help_item = replace_if_matched!(filtered_help_item, matched)

              # if it is last command, and there were changes                 
              if (i == (commands_with_identifiers.size - 2) && matched)
                n_filter_list << filtered_help_item
              end
            end
          end

          # we have just filtered those methods that have attribute for given entity 
          # and also are last in the list
          filtered_list = n_filter_list
        end

        # remove double spaces
        list = filtered_list.each { |e| e.first.gsub!(/  /,' ') }
      end

      if list.empty?
        shell.say ""
        shell.say "No tasks for current context '#{@@shell_context.active_context.full_path}'." 
      else  
        shell.say "Tasks:"
      end

      # monkey patching here => END
      shell.print_table(list, :indent => 2, :truncate => true)
      shell.say
      class_options_help(shell)
    end
  end
end