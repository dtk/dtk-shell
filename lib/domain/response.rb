dtk_require_dtk_common("rest_client_wrapper")

# This is wrapper for holding rest response information as well as 
# passing selection of ViewProcessor from Thor selection to render view 
# selection

module DTK
  module Client
    class Response < Common::Rest::Response

      attr_accessor :render_view

      def initialize(command_class=nil,hash={})
        super(hash)
        @command_class = command_class
        # default values
        @render_view = RenderView::AUG_SIMPLE_LIST 
      end

      def render_data
        if ok?()
          # if response is empty, response status is ok but no data is passed back
          if data.empty?
            data = {'Response' => 'OK'}
          end

          # sending raw data from response
          ViewProcessor.render(@command_class, data, @render_view,@render_data_type)
        else
          hash_part()
        end
      end

      def render_arg_list!
        @render_view = RenderView::AUG_SIMPLE_LIST
      end

      def render_table(data_type)
        @render_data_type   = data_type
        @render_view = RenderView::TABLE
      end

     private
      def hash_part()
        keys.inject(Hash.new){|h,k|h.merge(k => self[k])}
      end
    end

    class ResponseError < Response
      include Common::Rest::ResponseErrorMixin
      def initialize(hash={})
        super(nil,hash)
      end
    end

    class ResponseBadParams < ResponseError
      def initialize(bad_params_hash)
        errors = bad_params_hash.map do |k,v|
          {"code"=>"bad_parameter","message"=>"Parameter (#{k}) has a bad value: #{v}"}
        end
        hash = {"errors"=>errors, "status"=>"notok"}
        super(hash)
      end
    end

    class ResponseNoOp < Response
      def render_data
      end
    end

  end
end