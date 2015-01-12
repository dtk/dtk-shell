require 'yaml'

module DTK::Client
  module ReparseMixin
    YamlDTKMetaFiles = ['dtk.model.yaml', 'module_refs.yaml', 'assemblies/*.yaml', 'assemblies/*/assembly.yaml']

    def reparse_aux(location)
      files_yaml = YamlDTKMetaFiles.map{|rel_path|Dir.glob("#{location}/#{rel_path}")}.flatten(1)
      files_yaml.each do |file|
        file_content = File.open(file).read
        begin 
          YAML.load(file_content)
        rescue Exception => e
          e.to_s.gsub!(/\(<unknown>\)/,'')
          raise DTK::Client::DSLParsing::YAMLParsing.new("YAML parsing error #{e} in file", file)
        end
      end
      
      Response::Ok.new()
    end

  end
end
