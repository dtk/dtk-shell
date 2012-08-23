require 'thor'
require 'thor/group'

module DTK
  module Client
    class CommandBaseThor < Thor
      include CommandBase
      def initialize(args, opts, config)
        @conn = config[:conn]
        super
      end

      def self.execute_from_cli(conn,argv)
        ret = start(arg_analyzer(argv),:conn => conn)
        ret.kind_of?(Response) ? ret : ResponseNoOp.new
      end

      # Method will check if there ID/Name before one of the commands if so
      # it will route it properly by placing ID as last param
      def self.arg_analyzer(argv)
        task_names = all_tasks().map(&:first)
        
        # we are looking for case when task name is second options and ID/NAME is first
        # we replace '-' -> '_' due to thor defining task with '_' and invoking them with '-'
        unless argv.first == 'help'
          if (argv.size > 1 && task_names.include?(argv[1].gsub('-','_')))

            # Check if required params have been met, see UnboundMethod#arity
            method_definition = self.instance_method(argv[1].gsub('-','_').to_sym)
            # number two indicates here library id, taks name
            required_params = (method_definition.arity + 1).abs + 2

            if (argv.size < required_params)
              raise DTK::Client::DtkError, "Method 'dtk #{argv[1]}' requires at least #{required_params-argv.size} argument."
            end

            # first element goes on the end
            argv << argv.shift
          end
        end

        argv
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

        # we don't use subcommand print in case of root DTK class
        # for other classes Assembly, Node, etc. we print subcommand
        # this gives us console output: dtk assembly converge ASSEMBLY-ID
        super(args.empty? ? nil : args,not_dtk_clazz)

        # we will print error in case configuration has reported error
        @conn.print_warning if @conn.connection_error?
      end

    end
  end
end
