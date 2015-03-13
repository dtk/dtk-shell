class DTK::Client::Execute
  class Command
    dtk_require('command/rest_call')
    dtk_require('command/set_variable')

    attr_reader :result_var
    def initialize(hash)
      @hash_input = hash
      @result_var = (optional?(:result_var) || Iterate::ResultStore.default_var).to_sym
    end

    def print_form()
      # TODO: stub
      @hash_input.inspect
    end

   private
    def required(key)
      unless @hash_input.has_key?(key)
        raise ErrorUsage.new("Missing required key '#{key}' in: #{@hash_input.inspect}")
      end
      @hash_input[key]
    end
    def optional?(key)
      @hash_input[key]
    end
  end
end
