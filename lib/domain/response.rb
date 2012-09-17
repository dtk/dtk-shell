dtk_require_dtk_common("response")

# This is wrapper for holding rest response information as well as 
# passing selection of ViewProcessor from Thor selection to render view 
# selection

module DTK
  module Client
    #TODO: should make higher level class be above whether it is 'rest'
    class Response < Common::Response

      attr_accessor :render_view

      def initialize(command_class=nil,hash={})
        super(hash)
        @command_class = command_class
        # default values
        @render_view = RenderView::AUG_SIMPLE_LIST 
      end

      def self.wrap_helper_actions(&block)
        begin
          results = yield
          Ok.new(results)
         rescue ErrorUsage => e
          Error::Usage.new("message"=> e.to_s)
         rescue => e
          error_hash =  {
            "message"=> e.to_s,
            "backtrace" => e.backtrace
            }
          Error::Internal.new(error_hash)
        end
      end

      def render_data
        if ok?()

          # if response is empty, response status is ok but no data is passed back
          if data.empty?
            @render_view = RenderView::SIMPLE_LIST
            if data.kind_of?(Array)
              set_data('Message' => "Empty list")
            else #data.kind_of?(Hash)
              set_data('Status' => 'OK')
            end
          end

          # sending raw data from response
          ViewProcessor.render(@command_class, data, @render_view, @render_data_type)
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

      def hash_part()
        keys.inject(Hash.new){|h,k|h.merge(k => self[k])}
      end
      private :hash_part

      class Ok < self
        def initialize(data={})
          super(nil,{"data"=> data, "status" => "ok"})
        end
      end

      class Error < self
        include Common::Response::ErrorMixin
        def initialize(hash={})
          super(nil,{"errors" => [hash]})
        end
        
        class Usage < self
          def initialize(hash={})
            super({"code" => "error"}.merge(hash))
          end
        end
      
        class Internal < self
          def initialize(hash={})
            super({"code" => "error"}.merge(hash).merge("internal" => true))
          end
        end

        class NoOp < self
          def render_data
          end
        end
      end
    end
  end
end
