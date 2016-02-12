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
require 'colorize'
require 'readline'
require 'highline/import'

module DTK
  module Shell


    # we use interactive wizard to give user opertunity
    class InteractiveWizard

      PP_LINE_HEAD  = '--------------------------------- DATA ---------------------------------'
      PP_LINE       = '------------------------------------------------------------------------'
      INVALID_INPUT = Client::OsUtil.colorize(" Input is not valid. ", :yellow)
      EC2_REGIONS   = ['us-east-1','us-west-1','us-west-2','eu-west-1','sa-east-1','ap-northeast-1','ap-southeast-1','ap-southeast-2' ]


      def initialize
      end

      def self.validate_region(region)
        unless EC2_REGIONS.include? region
          raise ::DTK::Client::DtkValidationError.new("Region '#{region}' is not EC2 region, use one of: #{EC2_REGIONS.join(',')}")
        end
      end

      # Generic wizard which will return hash map based on metadata input
      #
      # Example provided bellow
      #
      def self.interactive_user_input(wizard_dsl, recursion_call = false)
        results = {}
        wizard_dsl = [wizard_dsl].flatten
        begin
          wizard_dsl.each do |meta_input|
            input_name = meta_input.keys.first
            display_name = input_name.to_s.gsub(/_/,' ').capitalize
            metadata = meta_input.values.first

            # default values
            output = display_name
            validation = metadata[:validation]
            is_password = false
            is_required = metadata[:requried]

            case metadata[:type]
              when nil
              when :email
                validation = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
              when :question
                output = "#{metadata[:question]}"
                validation = metadata[:validation]
              when :password
                is_password = true
                is_required = true
              when :repeat_password
                is_password = true
                is_required = true
                validation  = /^#{results[:password]}$/
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
                puts " Enter '#{display_name}': "
                results[input_name] = self.interactive_user_input(metadata[:options], true)
                next
            end

            input = text_input(output, is_required, validation, is_password)

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

      def self.text_input(output, is_required = false, validation_regex = nil, is_password = false)
        while line = ask("#{output}: ") { |q| q.echo = !is_password }
          if is_required && line.strip.empty?
            puts Client::OsUtil.colorize("Field '#{output}' is required field. ", :red)
            next
          end

          if validation_regex && !validation_regex.match(line)
            puts Client::OsUtil.colorize("Input is not valid, please enter it again. ", :red)
            next
          end

          return line
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
            datatype_info = (param_info['datatype'] ? DTK::Client::OsUtil.colorize(" [#{param_info['datatype'].upcase}]", :yellow) : '')
            string_identifier = DTK::Client::OsUtil.colorize(description, :green) + datatype_info

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

## EXAMPLE OF USAGE

# Example 1. Creating target via wizard
=begin
    desc "create","Wizard that will guide you trough creation of target and target-template"
    def create(context_params)

      # we get existing templates
      target_templates = post rest_url("target/list"), { :subtype => :template }

      # ask user to select target template
      wizard_params = [{:target_template => { :type => :selection, :options => target_templates['data'], :display_field => 'display_name', :skip_option => true }}]
      target_template_selected = DTK::Shell::InteractiveWizard.interactive_user_input(wizard_params)
      target_template_id = (target_template_selected[:target_template]||{})['id']

      wizard_params = [
        {:target_name     => {}},
        {:description      => {:optional => true }}
      ]

      if target_template_id.nil?
        # in case user has not selected template id we will needed information to create target
        wizard_params.concat([
          {:iaas_type       => { :type => :selection, :options => [:ec2] }},
          {:aws_install     => { :type => :question,
                                 :question => "Do we have your permission to add necessery 'key-pair' and 'security-group' to your EC2 account?",
                                 :options => ["yes","no"],
                                 :required_options => ["yes"],
                                 :explanation => "This permission is necessary for creation of a custom target."
                                }},
          {:iaas_properties => { :type => :group, :options => [
              {:key    => {}},
              {:secret => {}},
              {:region => {:type => :selection, :options => DTK::Shell::InteractiveWizard::EC2_REGIONS}},
          ]}},
        ])
      end

      post_body = DTK::Shell::InteractiveWizard.interactive_user_input(wizard_params)
      post_body ||= {}

      # this means that user has not given permission so we skip request
      return unless (target_template_id || post_body[:aws_install])

      # in case user chose target ID
      post_body.merge!(:target_template_id => target_template_id) if target_template_id


      response = post rest_url("target/create"), post_body
       # when changing context send request for getting latest targets instead of getting from cache
      @@invalidate_map << :target

      return response
    end
=end