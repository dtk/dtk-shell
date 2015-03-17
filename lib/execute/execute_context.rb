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
      @proxy = Proxy.new()
      result, command = instance_eval(&block)
      result
    end

    def method_missing(m, *args, &block)
      result, command = @proxy.send(m, *args, &block)
      if @print_results
        pp(:command => command.input_hash(),:result => result) 
      end
      [result, command]
    end

    # commands in the execute context
    class Proxy < self
      def call(object_type__method,params={})
        object_type, method = split_object_type__method(object_type__method)
        api_command = Command::APICall.new(:object_type => object_type, :method => method, :params => params)
        result = nil
        api_command.executable_commands.each do |command|
          result = CommandProcessor.execute(command)
        end
        [result, api_command]
      end
      
      def post_rest_call(path,body={})
        command = Command::RestCall::Post.new(:path => path,:body => body)
        result = CommandProcessor.execute(command)
        [result, command]
      end
    end

    private 
    # returns [object_type, method]
    def split_object_type__method(str)
      DelimitersObjectTypeMethod.each do |d| 
        if str =~ Regexp.new("(^[^#{d}]+)#{d}([^#{d}]+$)") 
          return [$1,$2]
        end
      end
      raise ErrorUsage.new("Illegal term '#{str}'")
    end

    DelimitersObjectTypeMethod = ['\/']
    

  end
end

