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
        super
        # we will print error in case configuration has reported error
        @conn.print_warning if @conn.connection_error?
      end

    end
  end
end
