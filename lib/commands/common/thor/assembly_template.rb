module DTK::Client
  module AssemblyTemplateMixin
    def get_assembly_name(assembly_id)
      name = nil
      3.times do
        name = get_name_from_id_helper(assembly_id)
        break if name
      end
      
      name
    end
    
    def get_assembly_stage_name(assembly_list,assembly_template_name)
      name = nil
      current_list = assembly_list.select{|e| e.include?(assembly_template_name)}
      
      if current_list.empty?
        name = assembly_template_name
      else
        numbers = []
        base_name = nil
        
        assembly_list.each do |assembly|
          match = assembly.match(/#{assembly_template_name}(-)(\d*)/)
          base_name = assembly_template_name if assembly_template_name.include?(assembly)
          numbers << match[2].to_i if match
        end
        
        unless base_name
          name = assembly_template_name
        else
          highest = numbers.max||1
          new_highest = highest+1
          
          all = (2..new_highest).to_a
          nums = all - numbers
          name = assembly_template_name + "-#{nums.first}"
        end
      end
      
      name
    end

    # the form should be
    # SETTINGS := SETTING[;...SETTING]
    # SETTING := ATOM || ATOM(ATTR=VAL,...)
    def parse_service_settings(settings)
       settings && settings.split(';').map{|setting|ServiceSetting.parse(setting)}
    end

    module ServiceSetting
      def self.parse(setting)
        if setting =~ /(^[^\(]+)\((.+)\)$/
          name = $1
          param_string = $2
          {:name => name, :parameters => parse_params(param_string)}
        else
          {:name => setting}
        end
      end
      private
       def self.parse_params(param_string)
         param_string.split(',').inject(Hash.new) do |h,av_pair|
           if av_pair =~ /(^[^=]+)=(.+$)/
             attr = $1
             val = $2
             h.merge(attr => val)
           else
             raise DtkError,"[ERROR] Settings param string is ill-formed"
           end
         end
       end
    end
  end
end
