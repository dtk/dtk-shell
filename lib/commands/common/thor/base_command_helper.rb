module DTK::Client
  class BaseCommandHelper
    def initialize(command,context_params=nil)
      @command        = command
      @context_params = context_params
      @options        = command.options
    end

    def print_external_dependencies(external_dependencies, location)
      ambiguous        = external_dependencies["ambiguous"]||[]
      amb_sorted       = ambiguous.map { |k,v| "#{k.split('/').last} (#{v.join(', ')})" }
      inconsistent     = external_dependencies["inconsistent"]||[]
      possibly_missing = external_dependencies["possibly_missing"]||[]

      OsUtil.print("There are inconsistent module dependencies mentioned #{location}: #{inconsistent.join(', ')}", :red) unless inconsistent.empty?
      OsUtil.print("There are missing module dependencies mentioned #{location}: #{possibly_missing.join(', ')}", :yellow) unless possibly_missing.empty?
      OsUtil.print("There are ambiguous module dependencies mentioned #{location}: '#{amb_sorted.join(', ')}'. One of the namespaces should be selected by editing the module_refs file", :yellow) if ambiguous && !ambiguous.empty?
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
