# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dtk-client/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Rich PELAVIN"]
  gem.email         = ["rich@reactor8.com"]
  gem.description   = %q{Dtk client is CLI tool used for communication with Reactor8.}
  gem.summary       = %q{DTK CLI client for R8 server interaction.}
  gem.homepage      = "https://github.com/rich-reactor8/dtk-client"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "dtk-client"
  gem.require_paths = ["lib"]
  gem.version       = DtkClient::VERSION

  gem.add_dependency 'bundler','>= 1.2.4'
  gem.add_dependency 'ruby-debug','>= 0.10.4'
  gem.add_dependency 'json','1.7.4'
  gem.add_dependency 'hirb','~> 0.7.0'
  gem.add_dependency 'thor','~> 0.15.4'
  gem.add_dependency 'activesupport','~> 3.2.12'
  gem.add_dependency 'erubis','~> 2.7.0'
  gem.add_dependency 'i18n','0.6.2'
  gem.add_dependency 'rest-client','~> 1.6.7'
  gem.add_dependency 'rspec','~> 2.12.0'
  gem.add_dependency 'grit','~> 2.5.0'
  gem.add_dependency 'dtk-common','>= 0.1.6'
  gem.add_dependency 'jenkins-client','~> 0.0.1'
  gem.add_dependency 'colorize','~> 0.5.8'
  gem.add_dependency 'fakeweb','~> 1.3.0'
  gem.add_dependency 'awesome_print','~> 1.1.0'
  #gem.add_dependency 'rdoc','= 3.12.1'
end