#
# Copyright (C) 2010-2016 dtk contributors
#
# This file is part of the dtk project.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'rubygems'

begin
  require File.expand_path("require_first", File.dirname(__FILE__))

  if gem_only_available?
    # loads it only if there is no common folder, and gem is installed
    require 'dtk_common_core'
  end

  # Load DTK Common
  dtk_require_dtk_common_core("dtk_common_core")

  # Monkey Patching bundler to support loading specific Gemfile from dtk-client project's root - Ticket: DTK-585
  dtk_require("config/configuration")

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