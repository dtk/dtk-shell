module DTK::Client
  module Commands
    module Common
      class Base
        def initialize(command_base,context_params)
          @command_base = command_base
          @context_params = context_params
        end
       private
        def retrieve_arguments(mapping)
          @context_params.retrieve_arguments(mapping,@command_base.method_argument_names())
        end

        def retrieve_thor_options(option_list)
          @context_params.retrieve_thor_options(option_list,@command_base.options)
        end

        def post(url_path,body=nil)
          @command_base.post(@command_base.rest_url(url_path),body)
        end
      end
    end
  end
end
