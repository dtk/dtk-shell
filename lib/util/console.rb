require 'readline'
dtk_require("os_util")

module DTK::Client
  module Console
    class << self

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
        # horizontal dash charcter
        h_dash = ["2014".hex].pack("U")

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
      def unix_shell(path=nil)

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
          while line = Readline.readline("unix-shell: ".colorize(:yellow), true)
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
        puts "[NOTICE] You are leaving unix-shell."
      end

    end
  end
end
