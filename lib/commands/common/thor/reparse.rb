require 'json'
require 'yaml'

module DTK::Client
  module ReparseMixin

    ##
    #
    # module_type: will be :component_module or :service_module
    def reparse_aux(location)
      files_json = Dir.glob("#{location}/**/*.json")
      files_yaml = Dir.glob("#{location}/**/*.yaml")

      files_json.each do |file|
        file_content = File.open(file).read
        begin 
          JSON.parse(file_content)
        rescue JSON::ParserError => e
          raise DTK::Client::DSLParsing::JSONParsing.new("JSON parsing error #{e} in file",file)
        end
      end

      files_yaml.each do |file|
        file_content = File.open(file).read
        begin 
          YAML.load(file_content)
        rescue Exception => e
          e.to_s.gsub!(/\(<unknown>\)/,'')
          raise DTK::Client::DSLParsing::YAMLParsing.new("YAML parsing error #{e} in file",file)
        end
      end
      
      Response::Ok.new()
    end

  end
end