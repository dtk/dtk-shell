class DTK::Client::Execute
  class Command
    dtk_require('command/rest_call')
    dtk_require('command/api_call')

    attr_reader :result_var,:input_hash
    def initialize(hash)
      @input_hash = hash
      @result_var = optional?(:result_var)
    end

   private
    def required(key)
      unless @input_hash.has_key?(key)
        raise ErrorUsage.new("Missing required key '#{key}' in: #{@input_hash.inspect}")
      end
      @input_hash[key]
    end
    def optional?(key)
      @input_hash[key]
    end
  end
end
