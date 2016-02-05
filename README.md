DTK Client
==============================


#### Description


DTK Client is a Ruby based CLI interface for communication with the DTK Server.
It's main purpose is to provide an easy to use interface for importing modules, browsing modules repository and deploying assemblies and topologies.

---
#### Sytstem requirements

- Ruby 1.9.3 
- Unix OS

---
#### Installation 

For DTK Client to work, following steps have to be done:

- Git User set up
- RSA Keys Generated

To install DTK Client gem, execute:
 
`gem install dtk-client`

---
#### Initial setup

There are two ways for DTK Client to run

- via an interactive shell (<tt>dtk-shell</tt>)
- by executing DTK Client commands (ie. <tt>dtk service list</tt>)

If it is the first time that the DTK Client is being used (by either of the ways), following prompts will appear: 

```
Please enter the DTK server address (example: instance.dtk.io)
Server address:

Please enter your DTK login details
Username:
Password:

```
After entering the correct data, following message will appear:
 
`SSH key 'dtk-client' added successfully!`

This means that the DTK Server has successfully registered DTK Client and the client is ready for use. 

---
#### DTK Client configuration

All of the DTK Configuration, installed component and service modules as well as client logs are located in `~/dtk`.

DTK Client configuration options, such as development option, verbose calls to DTK Server, log options and Client user credentials, can be configured in `~/dtk/client.conf`:

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
#### DTK Repoman

DTK Repoman is a Git based repository for publishing and installing component modules and service modules. DTK Repoman has it's own users, known as catalog users. The inital setup should register the DTK Client to the Public Catalog users. 

Successfully registered DTK Client on DTK Repoman enables execution of commands such as:

`dtk service-module list --remote` - lists service moduels on remote visible to the catalog user

`dtk component-module install namespace/component-module-name` - install component module 

Switching from public user to a commercial user can be done with `dtk account set-catalog-credentials`. This will initate a prompt for catalog username and password
