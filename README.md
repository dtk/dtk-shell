Dtk Client
==============================


#### Description


Dtk Client is a Ruby bas  ed CLI interface for communication with the Dtk Server.
It's main purpose is to provide an easy to use interface for importing modules, browsing modules repository and deploying assemblies and topologies.

---
#### Sytstem requirements

- Ruby 1.9.3
- Unix OS

---
#### Installation

For Dtk Client to work, following steps have to be done:

- Git User set up
- RSA Keys Generated

To install Dtk Client gem, execute:

`gem install dtk-client`

---
#### Initial setup

There are two ways for Dtk Client to run

- via an interactive shell (<tt>dtk-shell</tt>)
- by executing Dtk Client commands (ie. <tt>dtk service list</tt>)

If it is the first time that the Dtk Client is being used (by either of the ways), following prompts will appear:

```
Please enter the Dtk server address (example: instance.dtk.io)
Server address:

Please enter your Dtk login details
Username:
Password:

```
After entering the correct data, following message will appear:

`SSH key 'dtk-client' added successfully!`

This means that the Dtk Server has successfully registered Dtk Client and the client is ready for use.

---
#### Dtk Client configuration

All of the Dtk Configuration, installed component and service modules as well as client logs are located in `~/dtk`.

Dtk Client configuration options, such as development option, verbose calls to Dtk Server, log options and Client user credentials, can be configured in `~/dtk/client.conf`:

```
debug_task_frequency=5            # assembly - frequency between requests (seconds)
auto_commit_changes=false         # autocommit for modules
verbose_rest_calls=false          # logging of REST calls

module_location=component_modules
service_location=service_modules
test_module_location=test_modules
backups_location=backups


server_port=80
secure_connection_server_port=443
secure_connection=true
server_host=instance.dtk.io
```


User credentials are located in `~/dtk/.connection`

Component and Service modules that are installed, or modules that are imported are located in `~/dtk/component_modules` and `~/dtk/service_modules/`

---

## Advanced features
#### Development mode

When using Dtk Client in Development mode, gems from `Gemfile_dev` must be installed and used when running Dtk Client or Dtk Client Shell:

```
bundle install --gemfile Gemfile_dev
BUNDLE_GEMFILE=Gemfile_dev bundle exec ruby ./bin/dtk-shell
```

#### Dtk Repoman

Dtk Repoman is a Git based repository for publishing and installing component modules and service modules. Dtk Repoman has it's own users, known as catalog users. The inital setup should register the Dtk Client to the Public Catalog users.

Successfully registered Dtk Client on Dtk Repoman enables execution of commands such as:

`dtk service-module list --remote` - lists service moduels on remote visible to the catalog user

`dtk component-module install namespace/component-module-name` - install component module

Switching from public user to a commercial user can be done with `dtk account set-catalog-credentials`. This will initate a prompt for catalog username and password

## License

dtk-client is copyright (C) 2010-2016 dtk contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this work except in compliance with the License.
You may obtain a copy of the License in the [LICENSE](LICENSE) file, or at:

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
