#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
class Thor
  class << self
    # NOTE: Class is loaded automaticly in dtk-shell

    @@shell_context = nil
    HIDE_FROM_BASE_CONTEXT_HELP = "HIDE_FROM_BASE"

    def set_context(context)
      @@shell_context = context
    end

    def match_help_item_changes(help_item, entity_name)
      help_item.first.match(/^\[?#{entity_name.upcase}.?(NAME\/ID|ID\/NAME|ID|NAME)(\-?PATTERN)?\]?/)
    end

    def replace_if_matched!(help_item, matched)
      # change by reference
      help_item.first.gsub!(matched[0],'') if matched

      return help_item
    end

    # Method returns alternative providers
    def get_alternative_identifiers(command_name)
      # we check for alternate identifiers
      command_clazz = ::DTK::Client::OsUtil.get_dtk_class(command_name)

      if (command_clazz && command_clazz.respond_to?(:alternate_identifiers))
        return command_clazz.alternate_identifiers()
      end

      return []
    end

    # Monkey path of printable task methods to include name as well
    # Returns tasks ready to be printed.
    def printable_tasks(all = true, subcommand = false)
      (all ? all_tasks : tasks).map do |_, task|
        # using HIDE_FROM_BASE to hide command from base context help (e.g from dtk:/assembly>help) ...
        # but show that command in other context help (e.g in dtk:/assembly/assembly_id/utils>help)
        # added (task.name.eql?('help')) to hide help from command list
        next if (task.hidden? || (task.name.eql?("help")) || (task.usage.include?(HIDE_FROM_BASE_CONTEXT_HELP) && (@@shell_context ? !@@shell_context.active_context.is_n_context? : '')))
        item = []
        item << banner(task, false, subcommand)
        item << (task.description ? "# #{task.description.gsub(/\s+/m,' ')}" : "")
        item << task.name
        item
      end.compact
    end

    # method will check if help is overriden and if so it will replace help description,
    # with overriden one, override_tasks => class => OverrideTasks
    def overriden_help(override_tasks, help_item, is_command)
      return (override_tasks && override_tasks.are_there_self_override_tasks?) ? override_tasks.check_help_item(help_item, is_command) : help_item
    end

    def help(shell, subcommand = false)
      list = printable_tasks(true, subcommand)

      Thor::Util.thor_classes_in(self).each do |klass|
        list += klass.printable_tasks(false)
      end

      list.sort!{ |a,b| a[0] <=> b[0] }

      # monkey patching here => START
      if @@shell_context
        unless @@shell_context.root?

          active_context = @@shell_context.active_context

          # first command we are using:
          # e.g. dtk:\assembly\assembly1\node\node123> => command would be :assembly
          command             = active_context.first_command_name.upcase

          # is there identifier for given commands (first)
          # e.g. dtk:\assembly\assembly1\node\node123> => identifier here would be 'assembly1'
          is_there_identifier = active_context.is_there_identifier_for_first_context?

          # alternative providers
          alt_identifiers = get_alternative_identifiers(command)


          filtered_list = []

          # case when we are not on first level and it is not identifier we skip help
          # since it needs to be empty
          # e.g. assembly/bootstrap1/node> ... HELP IS EMPTY FOR THIS


          # override objects are special cases defined in Thor classes
          # base on level there will be included in help context, help content is calculated by:
          #
          # 1) Matching help items with Regex (see bellow)
          # 2) Adding help items from override_methods
          #
          #
          override_tasks_obj = self.respond_to?(:override_allowed_methods) ? self.override_allowed_methods.dup : nil

          shadow_list = ::DTK::Shell::ShadowEntity.resolve(active_context.last_context)
          # N-LEVEL-CONTEXT - context that has at least 2 commands and 1 or more identifiers
          # e.g. dtk:\assembly\assembly1\node>         THIS IS     N-LEVEL CONTEXT
          # e.g. dtk:\assembly\assembly1\node\node123> THIS IS     N-LEVEL CONTEXT
          # e.g. dtk:\assembly\assembly1>              THIS IS NOT N-LEVEL CONTEXT
          #
          unless shadow_list
            if (!active_context.is_n_context? || active_context.current_identifier?)

              list.each do |help_item|
                help_item.first.gsub!("^^", '') if help_item.first.include?("^^")

                # this will match entity_name (command) and alternative identifiers
                identifers = [command] + alt_identifiers

                # matches identifiers for ID/NAME
                matched_data          = help_item.first.match(/^\s\[?(#{identifers.join('|')}).?(NAME\/ID|ID\/NAME)\]?\s/)
                alt_matched_data      = help_item.first.match(/^\s\[?(#{alt_identifiers.join('|')}).?(NAME\/ID|ID\/NAME)\]?\s/)

                if matched_data.nil?
                  # not found and tier 1 we add it to help list
                  filtered_list << overriden_help(override_tasks_obj, help_item, true) if @@shell_context.current_command?
                else
                  # for help we only care about first context name / identifier
                  if !is_there_identifier
                    # if it contains [] it is optional and will be available on both tiers
                    if matched_data[0].include?('[')
                      # we remove it, since there is no need to use it
                      help_item.first.gsub!(matched_data[0],' ') unless help_item.nil?
                      filtered_list << overriden_help(override_tasks_obj, help_item, true)
                    end
                  else
                    # Adding alt identifiers here
                    if alt_matched_data
                      if active_context.current_alt_identifier?
                        help_item.first.gsub!(matched_data[0],'') unless help_item.nil?
                        filtered_list << overriden_help(override_tasks_obj, help_item, false)
                      end
                    else
                      unless active_context.current_alt_identifier?
                        help_item.first.gsub!(matched_data[0],'') unless help_item.nil?
                        filtered_list << overriden_help(override_tasks_obj, help_item, false)
                      end
                    end
                  end
                end
              end
            end

            # This will return commands that have identifiers
            # e.g. dtk:\assembly\assembly1\node\node123> => ['assembly','node']
            commands_that_have_identifiers =  active_context.commands_that_have_identifiers()
            is_n_level_context             = active_context.command_list.size > 1

            # first one does not count
            if is_n_level_context
              # additional filter list for n-context
              n_filter_list = []
              # we do not need first one, since above code takes care of that one
              filtered_list = filtered_list.select do |filtered_help_item|
                #next unless filtered_help_item
                unless commands_that_have_identifiers.empty?
                  commands_that_have_identifiers[1..-1].each_with_index do |entity,i|
                    matched = match_help_item_changes(filtered_help_item, entity)
                    filtered_help_item = replace_if_matched!(filtered_help_item, matched)

                    # if it is last command, and there were changes
                    if (i == (commands_that_have_identifiers.size - 2) && matched)
                      n_filter_list << filtered_help_item
                    end
                  end
                end
              end

              if override_tasks_obj && is_n_level_context
                last_entity_name = active_context.last_context_entity_name.to_sym

                # special case for node_id/utils (we don't want to use utils from service context)
                command_list = active_context.command_list
                if (command_list.size > 2) && command_list.last.eql?('utils')
                  last_entity_name = command_list.last(2).join('_').to_sym
                end

                # we get commands task, and identifier tasks for given entity (e.g. :assembly)
                command_o_tasks, identifier_o_tasks = override_tasks_obj.get_all_tasks(last_entity_name)

                if active_context.current_identifier?
                  identifier_o_tasks.each do |o_task|
                    n_filter_list << [o_task[1],o_task[2]]
                  end
                else
                  command_o_tasks.each do |o_task|
                    n_filter_list << [o_task[1],o_task[2]]
                  end
                end
              end

              # we have just filtered those methods that have attribute for given entity
              # and also are last in the list
              filtered_list = n_filter_list
            end

            # remove double spaces
            list = filtered_list.each { |e| e.first.gsub!(/  /,' ') }
          else
            list = shadow_list
          end
        end
      else
        # no dtk-shell just dtk, we make sure that underscore is not used '_'
        list = list.collect do |item|

          #
          # e.g.
          # dtk assembly_template info
          # dtk assembly-template info
          #
          item[0] = item[0].gsub(/^dtk ([a-zA-Z]+)_([a-zA-Z]+) /,'dtk \1-\2 ')
          item
        end
      end

      if list.empty?
        shell.say ""
        shell.say "No tasks for current context '#{@@shell_context.active_context.full_path}'."
      end

      # remove helper 3. element in help item list
      list = list.collect { |e| e[0..1] }

      # monkey patching here => END
      shell.print_table(list, :indent => 2, :truncate => true)
      shell.say


      # print sub context information
      sub_children = []

      # current active context clazz
      if @@shell_context
        last_command_name = @@shell_context.active_context.last_command_name
        command_clazz = DTK::Shell::Context.get_command_class(last_command_name)

        if @@shell_context && @@shell_context.active_context.current_identifier?
          sub_children += command_clazz.valid_children() if command_clazz.respond_to?(:valid_children)
          sub_children += command_clazz.invisible_context_list()
          # remove utils subcontext from help in service/service_name/node_group only
          if @@shell_context.active_context.last_context_is_shadow_entity? && @@shell_context.active_context.shadow_entity().eql?('node_group')
            sub_children.delete(:utils)
          end
        else
          if command_clazz.respond_to?(:validation_list)
            sub_children += ["#{last_command_name}-identifier"]
          end
        end

        unless sub_children.empty?
          shell.say("  Change context (cc) to: #{sub_children.join(', ')}", :BOLD)
          shell.say
        end
      end


      class_options_help(shell)
    end
  end
end