require 'colorize'
require 'readline'

module DTK
  module Shell

    # we use interactive wizard to give user opertunity
    class InteractiveWizard

      PP_LINE_HEAD = '--------------------------------- DATA ---------------------------------'
      PP_LINE      = '------------------------------------------------------------------------'
      

      def initialize
      end

      # takes hash maps with description of missing params and
      # returns array of hash map with key, value for each missed param

      def resolve_missing_params(param_list)
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
              user_provided_params << {:id => param_info['id'], :value => line}
              checkup_hash[param_info['description'].to_sym] = line
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

      def pretty_print_provided_user_info(user_information)
        puts PP_LINE_HEAD
        user_information.each do |key,value|
          printf "%48s : %s\n", key.to_s.colorize(:green), value.colorize(:yellow)
        end
        puts PP_LINE
        puts
      end
    end
  end
end
