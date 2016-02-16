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
require File.expand_path('../client', __FILE__)
require File.expand_path('../configurator', __FILE__)
require File.expand_path('../parser/adapters/thor',    __FILE__)
require File.expand_path('../shell/context', __FILE__)
require File.expand_path('../shell/domain/context_entity', __FILE__)
require File.expand_path('../shell/domain/active_context', __FILE__)
require File.expand_path('../shell/domain/context_params', __FILE__)
require File.expand_path('../shell/domain/override_tasks', __FILE__)
require File.expand_path('../shell/domain/shadow_entity', __FILE__)
require File.expand_path('../commands/thor/account', __FILE__)
require File.expand_path('../shell/parse_monkey_patch', __FILE__)
require File.expand_path('../shell/help_monkey_patch', __FILE__)
require File.expand_path('../execute/cli_pure/cli_rerouter', __FILE__)
require File.expand_path('../context_router', __FILE__)
