module DTK
  module Client
    module RenderView
      SIMPLE_LIST     = "simple_list"
      TABLE           = "table_print"
      PRETTY_PRINT    = "hash_pretty_print"
      AUG_SIMPLE_LIST = "augmented_simple_list"
    end

    class ViewProcessor
      class << self
        include Aux
        def render(command_class,ruby_obj,type,data_type,adapter=nil)
          adapter ||= get_adapter(type,command_class,data_type)

          if type == RenderView::TABLE
            # for table there is only one rendering, we use command class to
            # determine output of the table
            adapter.render(ruby_obj, command_class, data_type)

            # saying no additional print needed (see core class)
            return false
          elsif ruby_obj.kind_of?(Hash)
            adapter.render(ruby_obj)
          elsif ruby_obj.kind_of?(Array)
            ruby_obj.map{|el|render(command_class,el,type,nil,adapter)}
          else
            raise Error.new("ruby_obj has unexepected type")
          end
        end

        def get_adapter(type,command_class,data_type=nil)
          data_type_index = use_data_type_index?(command_class,data_type)
          cached = 
            if data_type_index
              ((AdapterCacheAug[type]||{})[command_class]||{})[data_type_index]
            else
              (AdapterCache[type]||{})[command_class]
            end

          return cached if cached
          dtk_nested_require("view_processor",type)
          klass = DTK::Client.const_get "ViewProc#{cap_form(type)}" 

          if data_type_index
            AdapterCacheAug[type] ||= Hash.new
            AdapterCacheAug[type][command_class] ||= Hash.new
            AdapterCacheAug[type][command_class][data_type_index] = klass.new(type,command_class,data_type_index)
          else
            AdapterCache[type] ||= Hash.new
            AdapterCache[type][command_class] = klass.new(type,command_class)
          end
        end
        AdapterCache = Hash.new
        AdapterCacheAug = Hash.new
      end
     private
      def initialize(type,command_class,data_type_index=nil)
        @command_class = command_class
        @data_type_index = data_type_index
      end

      #data_type_index is used if there is adata type passed and it is different than command_class defualt data type
      def self.use_data_type_index?(command_class,data_type)
        if data_type
         data_type_index = data_type.downcase
          if data_type_index != snake_form(command_class)
            data_type_index
          end
        end
      end

      def get_meta(type,command_class,data_type_index=nil)
        ret = nil
        view = data_type_index||snake_form(command_class)
        begin
          dtk_require("../views/#{view}/#{type}")
          ret = DTK::Client::ViewMeta.const_get cap_form(type)
         rescue Exception => e
          ret = failback_meta(command_class.respond_to?(:pretty_print_cols) ? command_class.pretty_print_cols() : [])
        end
        ret
      end
    end
    module ViewMeta
    end
  end
end
