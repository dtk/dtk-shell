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
# TODO-REMOVE: Check if we need this anymore

module DTK
  module Client
    #
    # Class is used as puppet wrapper, at the moment it will use console comamnds, later
    # to be replaced with direct usage of puppet code, or re-implentation of their direct calls
    #
    class DtkPuppet

      MODULE_PATH = OsUtil.component_clone_location()

      # installs puppet module from puppet forge via puppet module
      # method will print out progress or errrors
      #
      # Returns: Name of directory where module is saved
      def self.install_module(module_name)
        output = nil

        OsUtil.suspend_output do
          output = `puppet module install #{module_name} --modulepath #{MODULE_PATH} --force --render-as json`
        end

        # extract json from output, regex will match json in string
        matched = output.match(/\{.+\}/)

        raise DTK::Client::DtkError, "Puppet module '#{module_name}' not found." unless matched

        # parse matched json
        result = JSON.parse(matched[0])

        if result['result'] == 'failure'
          # we remove puppet specific messages
          filtered = result['error']['multiline'].gsub(/^.*puppet module.*$\n?/,'')
          # we strip and join multiline message
          filtered = filtered.split(/\n/).map(&:strip).join(', ')
          raise DTK::Client::DtkError, filtered
        end

        # puppet uses last part of the module name, as dir for location
        dir_name = module_name.split('-').last
        puts "Successfully installed '#{module_name}' from puppet forge, location: '#{MODULE_PATH}/#{dir_name}'"
        return dir_name
      end

    end
  end
end
