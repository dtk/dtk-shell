require 'colorize'
require 'readline'

module DTK
  module Shell


    # we use interactive wizard to give user opertunity
    class InteractiveWizard

      PP_LINE_HEAD  = '--------------------------------- DATA ---------------------------------'
      PP_LINE       = '------------------------------------------------------------------------'
      INVALID_INPUT = " Input is not valid.".colorize(:yellow)
      

      def initialize
      end

      # Generic wizard which will return hash map based on metadata input
      def self.interactive_user_input(wizard_dsl, recursion_call = false)
        results = {}
        
        begin
          wizard_dsl.each do |meta_input|
            input_name = meta_input.keys.first
            display_name = input_name.to_s.gsub(/_/,' ')
            metadata = meta_input.values.first
            case metadata[:type]
              when nil
                output = recursion_call ? "\t#{display_name.capitalize}: " : "Enter value for '#{display_name}': "
                validation = nil
              when :question
                output = "#{metadata[:question]} (#{metadata[:options].join('|')}): "
                validation = metadata[:options]
              when :selection
                options = ""
                display_field = metadata[:display_field]
                metadata[:options].each_with_index do |o,i|
                  if display_field
                    puts display_field
                    puts o
                    options += "\t#{i+1}. #{o[display_field]}\n"
                  else
                    options += "\t#{i+1}. #{o}\n"
                  end
                end
                output = "Select '#{display_name}': \n\n #{options} \n >> "
                validation = (1..metadata[:options].size).to_a
              when :group
                # recursion call to populate second level of hash params
                puts " Enter '#{display_name}' details: "
                results[input_name] = self.gandalf_the_gray(metadata[:options], true)
                next
            end

            input = resolve_input(output,validation,!metadata[:optional])

            if metadata[:required_options] && !metadata[:required_options].include?(input)
              # case where we have to give explicit permission, if answer is not affirmative
              # we terminate rest of the wizard
              puts " #{metadata[:explanation]}".colorize(:red)
              return nil
            end

            # post processing
            if metadata[:type] == :selection
              input = metadata[:options][input.to_i - 1]
            end

            results[input_name] = input
          end
        rescue Interrupt => e
          puts ""
          results = {}
        ensure
          return results
        end
      end


      def self.resolve_input(output, validation, is_required = true)

        while line = Readline.readline(" #{output}", false)
          if is_required && line.empty?
            puts INVALID_INPUT
            next
          end

          if !validation || validation.find { |val| line.eql?(val.to_s) }
            return line
          end

          puts INVALID_INPUT
        end
      end



      # takes hash maps with description of missing params and
      # returns array of hash map with key, value for each missed param
      def self.resolve_missing_params(param_list)
        begin
          user_provided_params, checkup_hash = [], {}

          puts "\nPlease fill in missing data.\n"
          param_list.each do |param_info|
            description =
              if param_info['display_name'] =~ Regexp.new(param_info['description'])
                param_info['display_name']
              else 
                "#{param_info['display_name']} (#{param_info['description']})"
              end
            string_identifier = description.colorize(:green) + " [#{param_info['datatype'].upcase}]".colorize(:yellow)

            puts "Please enter #{string_identifier}:"
            while line = Readline.readline(": ", true)
              id = param_info['id']
              user_provided_params << {:id => id, :value => line}
              checkup_hash[id] = {:value => line, :description => description}
              break
            end
            
          end

          # pp print for provided parameters
          pretty_print_provided_user_info(checkup_hash)

          # make sure this is satisfactory
          while line = Readline.readline("Is provided information ok? (yes|no) ", true)
            # start all over again
            return resolve_missing_params(param_list) if 'no'.eql? line 
            # continue with the code
            break if 'yes'.eql? line
          end

        rescue Interrupt => e
          puts 
          # TODO: Provide original error here 
          raise DTK::Client::DtkError, "You have decided to skip correction wizard."
        end

        return user_provided_params
      end

      private

      def self.pretty_print_provided_user_info(user_information)
        puts PP_LINE_HEAD
        user_information.each do |key,info|
          description = info[:description]
          value = info[:value]
          printf "%48s : %s\n", description.colorize(:green), value.colorize(:yellow)
        end
        puts PP_LINE
        puts
      end
    end
  end
end
