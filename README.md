DTK Client installation
==============================

To install DTK Client, follow these steps

- Ruby installation is required. Ruby 1.8.7 and 1.9.3 are officially supported.
- Add the R8 Gem repository to your Gem sources:  
`gem sources -a http://dtkuser:g3msdtk@gems-dev.r8network.com`
- Install the dtk-client gem:  
`gem install dtk-client`

- Type <tt>dtk</tt> or <tt>dtk-shell</tt> to start using the client  
On the first run, Client will present you with a wizard to enter your server and authentication info.

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

Development configuration setup
----------------------

- Copy `default.conf` from `lib/config`
- Rename copied file to `local.conf` and place it in `lib/config`
- Set configuration at will, local configuration is git ignored

NOTE: There is client configuration which can be found in `~/dtk/client.conf`. Local configuration takes presedence over any other configuration.

Configuration Setup
----------------------

- Create file <tt>~dtkconfig</tt> in you dtk dir (~/dtk) e.g. home/foo-user/dtk/connection.conf
  there you will define user credentials e.g.

```
username=abh
password=r8server
server_host=ec2-54-247-191-95.eu-west-1.compute.amazonaws.com
secure_connection=true
```
Run Tests
----------------------

- From dtk-client project root run <tt>rspec</tt>, this will run all unit tests

