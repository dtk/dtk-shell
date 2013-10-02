require 'colorize'
require 'readline'

module DTK
  module Shell


    # we use interactive wizard to give user opertunity
    class InteractiveWizard

      PP_LINE_HEAD  = '--------------------------------- DATA ---------------------------------'
      PP_LINE       = '------------------------------------------------------------------------'
      INVALID_INPUT = Client::OsUtil.colorize(" Input is not valid.", :yellow)
      EC2_REGIONS   = ['us-east-1','us-west-1','us-west-2','eu-west-1','sa-east-1','ap-northeast-1','ap-southeast-1','ap-southeast-2' ]
      

      def initialize
      end

      def self.validate_region(region)
        unless EC2_REGIONS.include? region
          raise ::DTK::Client::DtkValidationError.new("Region '#{region}' is not EC2 region, use one of: #{EC2_REGIONS.join(',')}", true) 
        end
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
                output = recursion_call ? "#{display_name.capitalize}: " : "Enter value for '#{display_name}': "
                validation = nil
              when :question
                output = "#{metadata[:question]} (#{metadata[:options].join('|')}): "
                validation = 
                metadata[:options]
              when :selection
                options = ""
                display_field = metadata[:display_field]
                metadata[:options].each_with_index do |o,i|
                  if display_field
                    options += "\t#{i+1}. #{o[display_field]}\n"
                  else
                    options += "\t#{i+1}. #{o}\n"
                  end
                end
                options += DTK::Client::OsUtil.colorize("\t0. Skip\n", :yellow) if metadata[:skip_option]
                output = "Select '#{display_name}': \n\n #{options} \n "
                validation_range_start = metadata[:skip_option] ? 0 : 1
                validation = (validation_range_start..metadata[:options].size).to_a
              when :group
                # recursion call to populate second level of hash params
                puts " Enter '#{display_name}' details: "
                results[input_name] = self.interactive_user_input(metadata[:options], true)
                next
            end

            input = resolve_input(output,validation,!metadata[:optional],recursion_call)

            if metadata[:required_options] && !metadata[:required_options].include?(input)
              # case where we have to give explicit permission, if answer is not affirmative
              # we terminate rest of the wizard
              DTK::Client::OsUtil.print(" #{metadata[:explanation]}", :red)
              return nil
            end

            # post processing
            if metadata[:type] == :selection
              input = input.to_i == 0 ? nil : metadata[:options][input.to_i - 1]
            end

            results[input_name] = input
          end

          return results
        rescue Interrupt => e
          puts
          raise DTK::Client::DtkValidationError, "Exiting the wizard ..."
        end
      end


      def self.resolve_input(output, validation, is_required, is_recursion_call)
        tab_prefix = is_recursion_call ? "\t" : ""

        # there was a bug within windows that does not support multiline input in readline method
        # following is the fix
        prompt_input =  " #{tab_prefix}#{output}"
        if output.match(/\n/)
          puts prompt_input
          prompt_input = ">> "
        end
        
        while line = Readline.readline(prompt_input, true)
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

            string_identifier = DTK::Client::OsUtil.colorize(description, :green) + DTK::Client::OsUtil.colorize(" [#{param_info['datatype'].upcase}]", :yellow)

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
          printf "%48s : %s\n", DTK::Client::OsUtil.colorize(description, :green), DTK::Client::OsUtil.colorize(value, :yellow)
        end
        puts PP_LINE
        puts
      end
    end
  end
end
