require 'colorize'
require 'readline'

module DTK
  module Shell

    # we use interactive wizard to give user opertunity
    class InteractiveWizard

      PP_LINE_HEAD = '--------------------------------- DATA ---------------------------------'
      PP_LINE      = '------------------------------------------------------------------------'
      

      def initialize
        @mock_up_response =   [
          {
            "id"=>2147515644,
            "description"=>"Application directory",
            "datatype"=>"string",
            "display_name"=>"server/thin/app_dir"
          },{
            "id"=>2147515645,
            "description"=>"Daemon User",
            "datatype"=>"string",
            "display_name"=>"server/thin/daemon_user"
          },{
            "id"=>2147515646,
            "description"=>"User name",
            "datatype"=>"string",
            "display_name"=>"server/dtk_server::tenant/name"
          },{
            "id"=>2147515648,
            "description"=>"DB name",
            "datatype"=>"string",
            "display_name"=>"server/dtk_postgresql::db/name"
          },{
            "id"=>2147515649,
            "description"=>"Client linux account name",
            "datatype"=>"string",
            "display_name"=>"server/gitolite::admin_client/name"
          }
        ]
      end

      # takes hash maps with description of missing params and
      # returns hash map with key, values for each missed param

      def resolve_missing_params(error_response)
        begin
          error_response ||= @mock_up_response
          user_provided_params = {}

          puts "\nResponse returned errors, please fill in missing data.\n"
          error_response.each do |error|

            string_identifier = error['description'].colorize(:green) + " (#{error['datatype'].upcase})".colorize(:yellow)

            puts "Please enter #{string_identifier}:"
            while line = Readline.readline(": ", true)
              user_provided_params[error['description'].to_sym] = line
              break
            end
            
          end

          # pp print for provided parameters
          pretty_print_provided_user_info(user_provided_params)

          # make sure this is satisfactory
          while line = Readline.readline("Is provided information ok? (yes|no) ", true)
            # start all over again
            return resolve_missing_params(error_response) if 'no'.eql? line 
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
