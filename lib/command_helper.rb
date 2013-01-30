module DTK; module Client
  module CommandHelperMixin
    def Helper(helper_class_name)
      unless Loaded[helper_class_name]
        dtk_nested_require('command_helpers',helper_class_name)
        Loaded[helper_class_name] = true
      end
      CommandHelper.const_get Common::Aux.snake_to_camel_case(helper_class_name.to_s)
    end
    Loaded = Hash.new
  end              

  #TODO: make all commands helpers a subclass of this
  class CommandHelper              
  end
end; end
