dtk_require_dtk_common("response")

# This is wrapper for holding rest response information as well as 
# passing selection of ViewProcessor from Thor selection to render view 
# selection

module DTK
  module Client
    #TODO: should make higher level class be above whether it is 'rest'
    class Response < Common::Response

      # :render_view        => symbol specifing type of data to be rendered e.g. :assembly
      # :skip_render        => flag that specifies that render is not needed (default: false)
      # :print_error_table  => we use it if we want to print 'error legend' for given tables (default: false)
      attr_accessor :render_view, :skip_render, :print_error_table

      def initialize(command_class=nil,hash={})
        super(hash)
        @command_class     = command_class
        @skip_render       = false
        @print_error_table = false
        # default values
        @render_view = RenderView::AUG_SIMPLE_LIST 
        @render_data_type = nil
      end

      def self.wrap_helper_actions(data={},&block)
        begin
          results = (block ? yield : data)
          Ok.new(results)
         rescue ErrorUsage => e
          Error::Usage.new("message"=> e.to_s)
         rescue => e
          error_hash =  {
            "message"=> e.inspect,
            "backtrace" => e.backtrace,
            "on_client" => true
            }
          Error::Internal.new(error_hash)
        end
      end

      def render_data(print_error_table=false)
        unless @skip_render
          if ok?()

            @print_error_table ||= print_error_table

            # if response is empty, response status is ok but no data is passed back
            if data.nil? or data.empty?
              @render_view = RenderView::SIMPLE_LIST
              if data.kind_of?(Array)
                set_data('Message' => "List is empty.")
              else #data.kind_of?(Hash)
                set_data('Status' => 'OK')
              end
            end

            # sending raw data from response
            ViewProcessor.render(@command_class, data, @render_view, @render_data_type, nil, @print_error_table)
          else
            hash_part()
          end
        end
      end

      def render_arg_list!
        @render_view = RenderView::AUG_SIMPLE_LIST
      end

      def set_datatype(data_type)
        @render_data_type = symbol_to_data_type_upcase(data_type)
        self
      end

      def render_table(data_type)
        @render_data_type = symbol_to_data_type_upcase(data_type)
        @render_view = RenderView::TABLE
        self
      end

      def hash_part()
        keys.inject(Hash.new){|h,k|h.merge(k => self[k])}
      end

      def symbol_to_data_type_upcase(data_type)
        return data_type.nil? ? nil : data_type.to_s.upcase
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
      end

      class NoOp < self
        def render_data
        end
      end
    end
  end
end

