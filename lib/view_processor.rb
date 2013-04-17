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
        include Auxiliary
        def render(command_class, ruby_obj, type, data_type, adapter=nil, print_error_table=false)
          adapter ||= get_adapter(type,command_class,data_type)
          if type == RenderView::TABLE
            # for table there is only one rendering, we use command class to
            # determine output of the table
            adapter.render(ruby_obj, command_class, data_type, nil, print_error_table)
              
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
        view = command_class if view.empty?
        # TODO: Fix this logic, but we first need to see what to do with simple lists
        if type.eql?('hash_pretty_print')
          return pretty_print_meta(command_class, data_type_index)
        end
   
        begin
          dtk_require("../views/#{view}/#{type}")
          view_const = DTK::Client::ViewMeta.const_get cap_form(view)
          ret = view_const.const_get cap_form(type)
         rescue Exception => e
             
          ret = failback_meta(command_class.respond_to?(:pretty_print_cols) ? command_class.pretty_print_cols() : [])
        end
           
        return ret
      end

      def pretty_print_meta(command_class,data_type_index=nil)
        view = data_type_index||snake_form(command_class)
        view = command_class if view.empty?
        # content = DiskCacher.new.fetch("http://localhost/mockup/get_pp_metadata", ::Config::Configuration.get(:meta_table_ttl))
        content = DiskCacher.new.fetch("pp_metadata", ::Config::Configuration.get(:meta_table_ttl))
        raise DTK::Client::DtkError, "Pretty print metadata is empty, please contact DTK team." if content.empty?
        hash_content = JSON.parse(content, {:symbolize_names => true})
        (view && (not view.empty?) && hash_content[view.to_sym])||empty_pretty_print_meta()
      end

      def empty_pretty_print_meta()
        {:top_type=>:top, :defs=>{:top_def=>[]}}
      end
    end
    module ViewMeta
    end
  end
end
