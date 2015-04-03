class DTK::Client::Execute
  class Script < self
    dtk_require('script/add_tenant')
    def self.execute()
      script_name = script_name()
      unless script_class = Scripts[script_name]
        raise ErrorUsage.new("Unsupported script '#{script_name}'")
      end
      script_class.execute_script()
    end
    Scripts = {
      'add-tenant' => AddTenant
    }
  
   private
    def self.script_name()
      unless ARGV.size > 0
        raise ErrorUsage.new("Script name must be given as first argument")
      end
      ARGV[0]
    end

    def self.execute_script()
      params = ret_params_from_argv()
      execute_with_params(params)
    end
    
    module OptionParserHelper
      require 'optparse'
      def process_params_from_options(banner,&block)
        OptionParser.new do |opts|
          opts.banner = banner
          block.call(opts)
        end.parse!
      end
      
      def show_help_and_exit(banner)
        ARGV[0] = '--help'
        OptionParser.new do |opts|
          opts.banner = banner
        end.parse!
      end
    end
    extend OptionParserHelper
  end
end

