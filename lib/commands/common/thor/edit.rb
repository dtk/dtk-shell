dtk_require_common_commands('thor/clone')
dtk_require_common_commands('thor/push_clone_changes')
dtk_require_common_commands('thor/pull_clone_changes')
dtk_require_common_commands('thor/reparse')
require 'yaml'

module DTK::Client
  module EditMixin
    include CloneMixin
    include PushCloneChangesMixin
    include PullCloneChangesMixin
    include ReparseMixin

    ##
    #
    # module_type: will be one of 
    # :component_module
    # :service_module 
    def edit_aux(module_type,module_id,module_name,version,opts={})
      module_location  = OsUtil.module_location(module_type,module_name,version,opts)

      pull_if_needed = opts[:pull_if_needed]
      # check if there is repository cloned 
      unless File.directory?(module_location)
        if opts[:automatically_clone] or Console.confirmation_prompt("Edit not possible, module '#{module_name}#{version && "-#{version}"}' has not been cloned. Would you like to clone module now"+'?')
          internal_trigger = true
          omit_output = true
          response = clone_aux(module_type,module_id,version,internal_trigger,omit_output,opts)
          # if error return
          return response unless response.ok?
          pull_if_needed = false
        else
          # user choose not to clone needed module
          return
        end
      end
      # here we should have desired module cloned

      if pull_if_needed
        response = pull_clone_changes?(module_type,module_id,version,opts)
        return response unless response.ok?
      end
      grit_adapter = Helper(:git_repo).create(module_location)
      if edit_info = opts[:edit_file]
        #TODO: cleanup so dont need :base_file_name
        file_to_edit = 
          if edit_info.kind_of?(String)
            edit_info
          else #edit_info.kind_of?(Hash) and has key :base_file_name
            base_file = edit_info[:base_file_name]
            (File.exists?("#{module_location}/#{base_file}.yaml") ? "#{base_file}.yaml" : "#{base_file}.json")
          end
        OsUtil.edit("#{module_location}/#{file_to_edit}")
        OsUtil.print("If you want to use different editor please set environment variable EDITOR and log back into dtk-shell!", :yellow) unless ENV['EDITOR']
      else
        Console.unix_shell(module_location, module_id, module_type, version)
      end

      unless grit_adapter.repo_exists?
        puts "Local module has been removed, skipping changes."
        return Response::Ok.new()
      end

      unless grit_adapter.changed?
        puts "No changes to repository"
        return Response::Ok.new()
      end

      unless file_to_edit
        grit_adapter.print_status
      end

      # check to see if auto commit flag
      auto_commit  = ::DTK::Configuration.get(:auto_commit_changes)
      confirmed_ok = false

      # if there is no auto commit ask for confirmation
      unless auto_commit
        confirm_msg = 
          if file_to_edit
            "Would you like to commit changes to the file?"
          else
            "Would you like to commit and push ALL the changes?"
          end
        confirmed_ok = Console.confirmation_prompt(confirm_msg)
      end
      if (auto_commit || confirmed_ok)
        if auto_commit 
          puts "[NOTICE] You are using auto-commit option, all changes you have made will be commited."
        end
        commit_msg = user_input("Commit message")

        # remove qoutes if they are not closed properly in commit_msg
        commit_msg.gsub!(/\"/,'') unless commit_msg.count('"') % 2 ==0

        internal_trigger=true
        reparse_aux(module_location)
        response = push_clone_changes_aux(module_type,module_id,version,commit_msg,internal_trigger,opts)
        
        # if error return
        return response unless response.ok?
      end

      #TODO: temporary took out; wil put back in        
      #puts "DTK SHELL TIP: Adding the client configuration parameter <config param name>=true will have the client automatically commit each time you exit edit mode" unless auto_commit
      Response::Ok.new()
    end

    def attribute_header()
      header_string = 
      "#############################\n####  REQUIRED ATTRIBUTES\n#############################\n#\n"
    end

    def attributes_editor(attributes,format)
      if (format.eql?('yaml'))
        dtk_folder = OsUtil.dtk_local_folder
        file_path = "#{dtk_folder}/temp_attrs.yaml"

        first_iteration_keys, first_iteration_values = [], []
        second_iteration_keys, second_iteration_values = [], []
        required_attributes = []
        
        attribute_pairs = YAML.load(attributes)
        
        attribute_pairs.each do |k,v|
          first_iteration_keys << k

          #prepare required attributes for editor display
          if v.eql?("*REQUIRED*")
            required_attributes << k 
            attribute_pairs[k] = nil
            v = nil
          end

          first_iteration_values << v
        end

        File.open(file_path, 'w') do |out|
          # print out required attributes
          unless required_attributes.empty?
            out.write(attribute_header())
            required_attributes.each do |req_attr|
              out.write("##{req_attr}\n")
            end
            out.write("#\n")
          end

          YAML.dump(attribute_pairs, out)
        end

        OsUtil.edit(file_path)
        OsUtil.print("If you want to use different editor please set environment variable EDITOR and log back into dtk-shell!", :yellow) unless ENV['EDITOR']
        begin
          edited = YAML.load_file(file_path)
        rescue Psych::SyntaxError => e
          raise DTK::Client::DSLParsing::YAMLParsing.new("YAML parsing error #{e} in file",file_path)
        end

        edited.each do |k,v|
          second_iteration_keys << k
          second_iteration_values << v
        end

        unless first_iteration_keys == second_iteration_keys
          edited_keys = second_iteration_keys.select{|k| !first_iteration_keys.include?(k)}
          raise DtkValidationError, "You have changed key(s) '#{edited_keys}'. We do not support key editing yet!"
        end
        
        raise DtkValidationError, "No attribute changes have been made." if ((first_iteration_keys == second_iteration_keys) && (first_iteration_values == second_iteration_values))
        edited
      else
        raise DTK::Client::DtkValidationError, "Unsupported format type '#{format.to_s}'!"
      end
    end

  end
end
