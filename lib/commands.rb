module DTK
  module Client
    module CommandBase
      #TODO: temp workaround
      def rotate_args(rotated_args)
        [rotated_args.last] + rotated_args[0..rotated_args.size-2]
      end

      def get(url)
        get_connection.get(self.class,url)
      end
      def post(url,body=nil)
        get_connection.post(self.class,url,body)
      end

      def post_file(url,body=nil)
        get_connection.post_file(self.class,url,body)
      end

      def rest_url(route)
        get_connection.rest_url(route)
      end

      def get_connection
        DTK::Client::Session.get_connection()
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
