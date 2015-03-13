class DTK::Client::Execute
  class ExecuteContext
    module ClassMixin
      def ExecuteContext(opts={},&block)
        ExecuteContext.new(opts).execute(&block)
      end
    end

    def initialize(opts={})
      @print_results = opts[:print_results]
    end

    def execute(&block)
      result, command = instance_eval(&block)
      if @print_results
        pp(:command => command.input_hash(),:result => result) 
      end
      result
    end

    # commands in teh execute context
    def post(path,body={})
      command = Command::RestCall::Post.new(:path => path,:body => body)
      result = CommandProcessor.execute(command)
      [result, command]
    end

  end
end

