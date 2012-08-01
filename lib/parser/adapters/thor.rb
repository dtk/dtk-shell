require 'thor'
module DTK
  module Client
    class CommandBaseThor < ::Thor
      include CommandBase
      def initialize(args, opts, config)
        @conn = config[:conn]
        super
      end

      def self.execute_from_cli(conn,argv)
        ret = start(argv,:conn => conn)
        ret.kind_of?(Response) ? ret : ResponseNoOp.new
      end

      desc "help [SUBCOMMAND]", "Describes available subcommands or one specific subcommand"
      def help(*args)
        not_dtk_clazz = true

        if defined?(DTK::Client::Dtk)
          not_dtk_clazz = !self.class.eql?(DTK::Client::Dtk)
        end

        # we don't use subcommand print in case of root DTK class
        # for other classes Assembly, Node, etc. we print subcommand
        # this gives us console output:
        # dtk assembly converge ASSEMBLY-ID
        super(nil,not_dtk_clazz)

        # we will print error in case configuration has reported error
        @conn.print_warning if @conn.connection_error?
      end

    end
  end
end
