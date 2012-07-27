DEVELOPMENT SETUP - DTK Client
==============================

Pre-requisites
----------------------

- Make sure you are using Ruby 1.8.7 , use following command to check<tt>ruby -v</tt>

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

- Create file <tt>etc/dtk/client.conf</tt> there you define server host e.g.

```
server_host=ec2-54-247-191-95.eu-west-1.compute.amazonaws.com
server_port=7000
```

- Create file <tt>.dtkclient</tt> in you home dir (~/.) e.g. home/foo-user/.dtkclient
  there you will define user credentials e.g.

```
username=abh
password=r8server
```
