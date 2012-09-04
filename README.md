DTK Client user install
==============================

This is guide only for user installation, development setup is bellow.

- Get the install script under <tt>https://github.com/rich-reactor8/dtk-client/blob/dtk_prefix/bundle/install_client.sh</tt>

- Run script with <tt>sudo bash install_client.sh</tt>
- When prompted use following values in wizard:

```
username=abh
password=r8server
server_host=ec2-54-247-191-95.eu-west-1.compute.amazonaws.com
server_port=7000
```

- Type <tt>dtk</tt> or <tt>dtk-shell</tt> to start using the client

DEVELOPMENT SETUP - DTK Client
==============================

Pre-requisites
----------------------

- Make sure you are using Ruby 1.8.7 , use following command to check ruby version <tt>ruby -v</tt>

Git setup
----------------------

- Make sure that you have clone dtk-common in same folder, use: 

```
git clone git@github.com:rich-reactor8/dtk-common.git dtk-common
```

Make sure that in same folder you have cloned dtk-common project. Also that project is under the same name.

Gem Setup
----------------------

- Make sure that you have bundler gem, check with <tt>gem list bundler</tt>
- If you don't have it install bundler gem <tt>gem install bundler</tt>
- Run bundle from dtk-client folder <tt>bundle install</tt>

Path Setup
----------------------

- Add dtk-client to PATH e.g.

```
export PATH=$PATH:/home/user/dtk-client/bin
```

Configuration Setup
----------------------

- Create file <tt>.dtkclient</tt> in you home dir (~/) e.g. home/foo-user/.dtkclient
  there you will define user credentials e.g.

```
username=abh
password=r8server
server_host=ec2-54-247-191-95.eu-west-1.compute.amazonaws.com
server_port=7000
```
Run Tests
----------------------

- From dtk-client project root run <tt>rspec</tt>, this will run all unit tests

