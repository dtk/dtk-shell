module DTK
  module Client
    module CommandBase
      #TODO: temp workaround
      def rotate_args(rotated_args)
        [rotated_args.last] + rotated_args[0..rotated_args.size-2]
      end

      def self.execute_from_cli(conn,argv)
        ret = start(argv,:conn => conn)
        ret.kind_of?(Response) ? ret : ResponseNoOp.new
      end

      def get(url)
        @conn.get(self.class,url)
      end
      def post(url,body=nil)
        @conn.post(self.class,url,body)
      end
      def rest_url(route)
        @conn.rest_url(route)
      end

      def self.handle_argument_error(task, error) 
        super
      end

     private

      def pretty_print_cols()
        self.class.pretty_print_cols()
      end
    end
  
  end
end
