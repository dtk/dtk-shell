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
require 'singleton'
dtk_require("config/disk_cacher")

class PPColumns

  include Singleton

  def initialize
    # content = DiskCacher.new.fetch("http://localhost/mockup/get_const_metadata", ::DTK::Configuration.get(:meta_constants_ttl))
    content = DiskCacher.new.fetch("const_metadata", ::DTK::Configuration.get(:meta_constants_ttl))
    raise DTK::Client::DtkError, "Require constants metadata is empty, please contact DTK team." if content.empty?
    @constants = JSON.parse(content)
  end

  def self.get(symbol_identifier)
    return PPColumns.instance.get(symbol_identifier)
  end

  def get(symbol_identifier)
    return @constants[symbol_identifier.to_s]
  end

end