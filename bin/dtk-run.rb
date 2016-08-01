#!/usr/bin/env ruby
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

# GLOBAL IDENTIFIER
$shell_mode = false

require File.expand_path('../lib/client', File.dirname(__FILE__))
require File.expand_path('../lib/configurator', File.dirname(__FILE__))
require File.expand_path('../lib/parser/adapters/thor', File.dirname(__FILE__))
require File.expand_path('../lib/shell/context', File.dirname(__FILE__))
require File.expand_path('../lib/shell/domain/context_entity', File.dirname(__FILE__))
require File.expand_path('../lib/shell/domain/active_context', File.dirname(__FILE__))
require File.expand_path('../lib/shell/domain/context_params', File.dirname(__FILE__))
require File.expand_path('../lib/shell/domain/override_tasks', File.dirname(__FILE__))
require File.expand_path('../lib/shell/domain/shadow_entity', File.dirname(__FILE__))
require File.expand_path('../lib/commands/thor/account', File.dirname(__FILE__))
require File.expand_path('../lib/shell/parse_monkey_patch', File.dirname(__FILE__))
require File.expand_path('../lib/shell/help_monkey_patch', File.dirname(__FILE__))
require File.expand_path('../lib/execute/cli_pure/cli_rerouter', File.dirname(__FILE__))

paths = []
paths << File.expand_path('../lib/commands/thor/*.rb', File.dirname(__FILE__))
paths << File.expand_path('../lib/commands/common/thor/*.rb', File.dirname(__FILE__))

paths.each do |path|
  Dir[path].each do |thor_class_file|
    require thor_class_file
  end
end



require 'shellwords'
require 'json'

$: << "/usr/lib/ruby/1.8/" #TODO: put in to get around path problem in rvm 1.9.2 environment

config_exists = ::DTK::Client::Configurator.check_config_exists
::DTK::Client::Configurator.check_git
::DTK::Client::Configurator.create_missing_clone_dirs


# check if .add_direct_access file exists, if not then add direct access and create .add_direct_access file
resolve_direct_access(::DTK::Client::Configurator.check_direct_access, config_exists)
entries = []

if ARGV.size > 0
  entries = ARGV
  entries = DTK::Shell::Context.check_for_sym_link(entries)
  entity_name = entries.shift
end

# special case for when no params are provided use help method
if (entity_name == 'help' || entity_name.nil?)
  entity_name = 'dtk-run'
  args = ['help']
else
  args = entries
end

context = DTK::Shell::Context.new(true)

begin
  if ::DTK::CLIRerouter.is_candidate?(entity_name, args)
    response_obj = ::DTK::CLIRerouter.new(entity_name, args).run()
    puts response_obj.to_json
  else
    # default execution
    entity_name, method_name, context_params, thor_options = context.get_dtk_command_parameters(entity_name, args)
    top_level_execute(entity_name, method_name, context_params, thor_options, false)
  end
rescue DTK::Client::DtkError => e
  DtkLogger.instance.error(e.message, true)
rescue Exception => e
  DtkLogger.instance.error_pp(e.message, e.backtrace)
end