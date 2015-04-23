class DTK::Client::Execute
  class Script < self
    dtk_require('script/add_tenant')
    def self.execute()
      script_class().execute_script()
    end
  
   private
    Scripts = {
      'add-tenant' => AddTenant,
    }

    def self.script_class()
      script_name = ARGV.size > 0 && ARGV[0]
      unless script_class = script_name && Scripts[script_name]
        legal_scripts = Scripts.keys
           err_msg = (script_name ? "Unsupported script '#{script_name}'" : "Missing script name")
        err_msg << "; supported scripts are (#{legal_scripts.join(',')})"
        raise ErrorUsage.new(err_msg)
      end
      script_class
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

