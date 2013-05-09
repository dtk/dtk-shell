module Bundler
  module SharedHelpers

    private 
    def find_gemfile
    	if DTK::Configuration.get(:development_mode)
    		File.expand_path('../Gemfile_dev', File.dirname(__FILE__))
    	else
    		File.expand_path('../Gemfile', File.dirname(__FILE__))
    	end
    end
  end
end
