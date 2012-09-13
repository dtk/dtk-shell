class Thor
  class << self

    @@shell_context = nil

    def set_context(context)
      @@shell_context = context
    end

    def help(shell, subcommand = false)
      list = printable_tasks(true, subcommand)
      Thor::Util.thor_classes_in(self).each do |klass|
        list += klass.printable_tasks(false)
      end
      list.sort!{ |a,b| a[0] <=> b[0] }

      # monkey patching here => START
      unless @@shell_context.root?
        command=@@shell_context.tier_1_command.upcase
        filtered_list = []

        list.each do |help_item|
          # matches identifiers for ID/NAME
          matched_data = help_item.first.match(/\s\[?#{command}.?(NAME\/ID|ID\/NAME)\]?\s/)
          if matched_data.nil?
            # not found and tier 1 we add it to help list
            filtered_list << help_item if @@shell_context.tier_1?
          else
            unless @@shell_context.tier_1?
              # found and tier 2 we add it to list and remove ID/NAME part of desc
              filtered_list << help_item.first.gsub(matched_data[0],'')
            else
               # if it contains [] it is optional and will be available on both tiers
              filtered_list << help_item  if matched_data[0].include?('[')
            end            
          end
        end

        list = filtered_list
      end


      if list.empty?
        shell.say "No tasks for current context '#{@@shell_context.active_commands.join('/')}'." 
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