require 'rubygems'

begin
  require File.expand_path("require_first", File.dirname(__FILE__))

  if gem_only_available?
    # loads it only if there is no common folder, and gem is installed
    require 'dtk-common'
  end

  # Monkey Patching bundler to support loading specific Gemfile from dtk-client project's root - Ticket: DTK-585
  dtk_require("config/configuration")


  if DTK::Configuration.get(:development_mode)
    require 'grit'
    # enable grit debug logs
    Grit.debug = true
  end

  # we don't need Bundler.setup but will leave it commented just in case
  # TODO: This is temp solution which will not use bundler.setup when in dev mode
  # thus allowing us to use system gems and not just the ones specified in Gemfile
  unless DTK::Configuration.get(:development_mode)
    require 'bundler'
    #TODO: rich temp hack becaus eof problem with gem dependencies; changed this because it was not working in 0.19.0
    if Bundler.respond_to?(:start)
      Bundler.start
    end
    dtk_require("bundler_monkey_patch")
  end

  #TODO: should be common gem
  dtk_require_dtk_common("hash_object")
  dtk_require_dtk_common("auxiliary")

  ########
  dtk_require("auxiliary")
  dtk_require("core")
  dtk_require("error")
  dtk_require("dtk_constants")
  dtk_require("commands")
  dtk_require("view_processor")
  dtk_require("search_hash")
  dtk_require("dtk_logger")
rescue SystemExit, Interrupt
  #puts "DTK Client action canceled."
  exit(1)
end


