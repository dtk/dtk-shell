module DTK::Client
  module AssemblyTemplateMixin
    # the form should be
    # SETTINGS := SETTING[;...SETTING]
    # SETTING := ATOM || ATOM(ATTR=VAL,...)
    def parse_service_settings(settings)
      # TODO: because of problem with serialization on server side just passing in raw settings string
      #  settings && settings.split(';').map{|setting|ServiceSetting.parse(setting)}
      settings
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
