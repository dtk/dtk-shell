require 'readline'
require 'shellwords'

dtk_require("os_util")
dtk_require_common_commands('../common/thor/push_clone_changes')
dtk_require_from_base("command_helper")

module DTK::Client
  module Console
    class << self
      include PushCloneChangesMixin
      include CommandBase
      include CommandHelperMixin

      EDIT_MODULE_COMMANDS = ['cd', 'exit', 'dtk-push-changes', 'ls']

      # Display confirmation prompt and repeat message until expected answer is given
      def confirmation_prompt(message, add_options=true)
        # used to disable skip with ctrl+c
        trap("INT", "SIG_IGN")
        message += " (yes|no)" if add_options

        while line = Readline.readline("#{message}: ", true)
          if (line.eql?("yes") || line.eql?("y"))
            trap("INT",false)
            return true
          elsif (line.eql?("no") || line.eql?("n"))
            trap("INT",false)
            return false
          end
        end
      end

      # Loading output used to display waiting status
      def wait_animation(message, time_seconds)
        print message
        print " [     ]"
        STDOUT.flush
        time_seconds.downto(1) do
          1.upto(4) do |i|
            next_output = "\b\b\b\b\b\b\b"
            case
             when i % 4 == 0
              next_output  += "[ =   ]"
             when i % 3 == 0
               next_output += "[  =  ]"
             when i % 2 == 0
              next_output  += "[   = ]"
             else
              next_output  += "[  =  ]"
            end

            print next_output
            STDOUT.flush
            sleep(0.25)
          end
        end
        # remove loading animation
        print "\b\b\b\b\b\b\bRefreshing..."
        STDOUT.flush
        puts 
      end


      ##
      # Method that will execute until interupted as unix like shell. As input takes
      # path to desire directory from where unix shell can execute normaly.
      #
      def unix_shell(path=nil, module_id=nil, module_type=nil, version=nil)
        
        dtk_shell_ac_proc = Readline.completion_proc
        dtk_shell_ac_append_char = Readline.completion_append_character

        if OsUtil.is_windows?
          puts "[NOTICE] Unix shell interaction is currenly not supported on Windows."
          return
        end

        application_dir     = Dir.getwd()
        # if no directory provided we are using application shell
        path = path || application_dir
        # we need to change path like this since system call 'cd' is not supported
        Dir.chdir(path)
        puts "[NOTICE] You are switching to unix-shell, to path #{path}"
        begin
          prompt = DTK::Client::OsUtil.colorize("unix-shell: ", :yellow)
          Readline.completion_append_character = ""
          Readline.completion_proc = Proc.new do |str|
            EDIT_MODULE_COMMANDS.concat(Dir[str+'*'].grep(/^#{Regexp.escape(str)}/))
          end
          while line = Readline.readline(prompt, true)
            begin
              line = line.chomp()
              break if line.eql?('exit')
              # since we are not able to support cd command due to ruby specific restrictions
              # we will be using chdir to this.
              if (line.match(/^cd /))
                # remove cd part of command
                line = line.gsub(/^cd /,'')
                # does the command start with '/'
                if (line.match(/^\//))
                  # if so just go to desired line
                  Dir.chdir(line)
                else
                  # we created wanted path 
                  Dir.chdir("#{Dir.getwd()}/#{line}")
                end
              # elsif line.eql?('dtk-push-changes')
              elsif line.match(/^dtk-push-changes/)
                args       = Shellwords.split(line)
                commit_msg = nil

                unless args.size==1
                  raise DTK::Client::DtkValidationError, "To push changes to server use 'dtk-push-changes [-m COMMIT-MSG]'" unless (args[1]=="-m" && args.size==3)
                  commit_msg = args.last
                end

                response = push_clone_changes_aux(module_type, module_id, version, commit_msg)
                puts response["data"][:json_diffs]
                puts "commit_sha: #{response["data"][:commit_sha]}"
                puts "commit_msg: #{commit_msg}" unless commit_msg.nil?
              else
                system(line)        
              end
            rescue Exception => e
              puts e.message
            end
          end
        rescue Interrupt
          puts ""
          # do nothing else
        end

        Readline.completion_append_character = dtk_shell_ac_append_char
        Readline.completion_proc = dtk_shell_ac_proc
        puts "[NOTICE] You are leaving unix-shell."
      end

    end
  end
end
