require 'thor'
require 'thor/group'

module DTK
  module Client
    class CommandBaseThor < Thor
      include CommandBase
      extend  CommandBase
      
      def initialize(args, opts, config)
        @conn = config[:conn]
        super
      end

      def self.execute_from_cli(conn,argv,shell_execution=false)
        @@shell_execution = shell_execution
        ret = start(arg_analyzer(argv),:conn => conn)
        ret.kind_of?(Response) ? ret : ResponseNoOp.new
      end

      # Method will check if there ID/Name before one of the commands if so
      # it will route it properly by placing ID as last param
      def self.arg_analyzer(argv)
        all_task_names = task_names()
        
        # we are looking for case when task name is second options and ID/NAME is first
        unless argv.first == 'help'
          if (argv.size > 1 && all_task_names.include?(argv[1]))

            # check if required params have been met, see UnboundMethod#arity
            method_definition = self.instance_method(argv[1].gsub('-','_').to_sym)

            # if negative it means that it has optional parameters, required number is negative value + 1
            required_params = (method_definition.arity < 0) ? method_definition.arity+1 : method_definition.arity

            # number 1 indicates here TASK NAME
            if (argv.size < required_params + 1)
              raise DTK::Client::DtkError, "Method 'dtk #{argv[1]}' requires at least #{required_params-argv.size} argument."
            end

            # first element goes on the end
            argv << argv.shift
          end
        end

        argv
      end

      # returns all task names for given thor class with use friendly names (with '-' instead '_')
      def self.task_names
        task_names = all_tasks().map(&:first).collect { |item| item.gsub('_','-')}
      end

      no_tasks do 
        # Method not implemented error
        def not_implemented
          raise DTK::Client::DtkError, "Method NOT IMPLEMENTED!"
        end
      end

      ##
      # This is fix where we wanna exclude basename print when using dtk-shell.
      # Thor has banner method, representing row when help is invoked. As such banner
      # will print out basename first. e.g.
      #
      # dtk-shell assembly list [library|target]         # List asssemblies in library or target
      #
      # Basename is derived from name of file, as such can be overriden to serve some other
      # logic.
      #
      def self.basename
        basename = super
        basename = '' if basename == 'dtk-shell'
        return basename
      end

      desc "help [SUBCOMMAND]", "Describes available subcommands or one specific subcommand"
      def help(*args)
        not_dtk_clazz = true

        if defined?(DTK::Client::Dtk)
          not_dtk_clazz = !self.class.eql?(DTK::Client::Dtk)
        end

        # not_dtk_clazz - we don't use subcommand print in case of root DTK class
        # for other classes Assembly, Node, etc. we print subcommand
        # this gives us console output: dtk assembly converge ASSEMBLY-ID
        #
        # @@shell_execution - if we run from shell we don't want subcommand output
        #
        super(args.empty? ? nil : args, not_dtk_clazz && !@@shell_execution)

        # we will print error in case configuration has reported error
        @conn.print_warning if @conn.connection_error?
      end
    end
  end
end
