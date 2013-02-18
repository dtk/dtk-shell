module Bundler
  module SharedHelpers

    private 
    def find_gemfile
    	File.expand_path('../Gemfile', File.dirname(__FILE__))
    end
  end
end
