# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dtk-shell/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Rich PELAVIN"]
  gem.email         = ["rich@reactor8.com"]
  gem.description   = %q{The DTK Client is a command line tool to interact with your DTK Server and DTK Service Catalog instance(s).}
  gem.summary       = %q{DTK CLI client for DTK server interaction.}
  gem.homepage      = "https://github.com/rich-reactor8/dtk-shell"
  gem.licenses      = ["Apache-2.0"]

  gem.files = %w(README.md Gemfile Gemfile_dev dtk-shell.gemspec)
  gem.files += Dir.glob("bin/**/*")
  gem.files += Dir.glob("lib/**/*")
  gem.files += Dir.glob("puppet/**/*")
  gem.files += Dir.glob("spec/**/*")
  gem.files += Dir.glob("views/**/*")

  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "dtk-shell"
  gem.require_paths = ["lib"]
  gem.version       = DtkShell::VERSION

  gem.add_dependency 'mime-types','~> 2.99.3'
  gem.add_dependency 'bundler','>= 1.2.4'
  gem.add_dependency 'json_pure' ,'1.7.4'
  gem.add_dependency 'diff-lcs','1.2.0'
  gem.add_dependency 'hirb','~> 0.7.0'
  gem.add_dependency 'thor','~> 0.15.4'
  gem.add_dependency 'erubis','~> 2.7.0'
  gem.add_dependency 'dtk-common-core','0.11.0'
  gem.add_dependency 'git','1.2.9'
  # gem.add_dependency 'colorize','~> 0.5.8'
  gem.add_dependency 'colorize', '0.7.7'
  gem.add_dependency 'highline', '1.7.8'
  gem.add_dependency 'awesome_print', '1.1.0'

  # gem.add_dependency 'rb-readline', '0.5.0'
  # gem.add_dependency 'activesupport','~> 3.2.12'
  # gem.add_dependency 'i18n','0.6.1'
  # gem.add_dependency 'puppet','~> 3.1.0'
  # gem.add_dependency 'jenkins-client','~> 0.0.1'
  # gem.add_dependency 'rspec','~> 2.12.0'
  # gem.add_dependency 'awesome_print','~> 1.1.0'
  # gem.add_dependency 'rdoc','= 3.12.1'l
  # gem.add_development_dependency 'ruby-debug','>= 0.10.4'
  # gem.add_development_dependency 'awesome_print','>= 1.1.0'
  # gem.add_development_dependency 'rspec','~> 2.12.0'
end
