module DTK::Client
  class BaseCommandHelper
    def initialize(command,context_params=nil)
      @command        = command
      @context_params = context_params
      @options        = command.options
    end

   private
    def context_params()
      @context_params ||  raise(DtkError, "[ERROR] @context_params is nil")
    end

    def retrieve_arguments(mapping, method_info = nil)
      context_params.retrieve_arguments(mapping, method_info || @command.method_argument_names)
    end

    def get_namespace_and_name(*args)
      @command.get_namespace_and_name(*args)
    end

    def rest_url(*args)
      @command.rest_url(*args)
    end

    def post(*args)
      @command.post(*args)
    end

  end
end
