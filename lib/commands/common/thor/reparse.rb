require 'json'

module DTK::Client
  module ReparseMixin

    ##
    #
    # module_type: will be :component_module or :service_module
    def reparse_aux(location)
      files = Dir.glob("#{location}/**/*.json")

      files.each do |file|
        file_content = File.open(file).read
        
        begin 
          JSON.parse(file_content)
        rescue JSON::ParserError => e
          raise DTK::Client::DtkValidationError::JSONParsing.new(e,file)
        end
      end
      
      Response::Ok.new()
    end

  end
end