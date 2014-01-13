components = [
{:namespace => 'dtk18',:name => 'storm'},
{:namespace => 'dtk18',:name => 'unit_test'},
{:namespace => 'dtk18',:name => 'accumulo'},
{:namespace => 'dtk17',:name => 'test'},
{:namespace => 'r8',:name => 'wordpress'},
{:namespace => 'dtk17',:name => 'redis'},
{:namespace => 'r8',:name => 'mongodb'},
{:namespace => 'r8',:name => 'ntp'},
{:namespace => 'r8',:name => 'bootstrap'},
{:namespace => 'r8',:name => 'common_user'},
{:namespace => 'r8',:name => 'dtk'},
{:namespace => 'r8',:name => 'dtk_activemq'},
{:namespace => 'r8',:name => 'dtk_java'},
{:namespace => 'r8',:name => 'dtk_postgresql'},
{:namespace => 'r8',:name => 'dtk_repo_manager'},
{:namespace => 'r8',:name => 'dtk_server'},
{:namespace => 'r8',:name => 'dtk_thin'},
{:namespace => 'r8',:name => 'gitolite'},
{:namespace => 'r8',:name => 'r8_base'},
{:namespace => 'r8',:name => 'stdlib'},
{:namespace => 'r8',:name => 'thin'},
{:namespace => 'r8',:name => 'apache'},
{:namespace => 'r8',:name => 'apt'},
{:namespace => 'r8',:name => 'bigtop_base'},
{:namespace => 'r8',:name => 'hadoop'},
{:namespace => 'r8',:name => 'hadoop_zookeeper'},
{:namespace => 'r8',:name => 'hdp'},
{:namespace => 'r8',:name => 'hdp-hadoop'},
{:namespace => 'r8',:name => 'hdp-hcat'},
{:namespace => 'r8',:name => 'java'},
{:namespace => 'r8',:name => 'jmeter'},
{:namespace => 'r8',:name => 'ldap'},
{:namespace => 'r8',:name => 'logrotate'},
{:namespace => 'r8',:name => 'nginx'},
{:namespace => 'r8',:name => 'dtk_user'},
{:namespace => 'r8',:name => 'vcsrepo'},
{:namespace => 'r8',:name => 'mysql'},
{:namespace => 'dtk17',:name => 'temp'},
{:namespace => 'dtk17',:name => 'rsync'},
{:namespace => 'r8',:name => 'dtk_nginx'},
{:namespace => 'dtk18',:name => 'dtk_apt'},
{:namespace => 'dtk18',:name => 'logstash'}
]

services = [
  {:namespace => 'dtk18',:name => 'unit_test'},
{:namespace => 'r8',:name => 'wordpress_test'},
{:namespace => 'r8',:name => 'bakir_test'},
{:namespace => 'dtk17',:name => 'redis_test'},
{:namespace => 'r8',:name => 'hadoop_test'},
{:namespace => 'r8',:name => 'mongodb_test'},
{:namespace => 'r8',:name => 'dtk'},
{:namespace => 'r8',:name => 'bigtop'},
{:namespace => 'r8',:name => 'bootstrap'},
{:namespace => 'r8',:name => 'bakir_test_apache'},
{:namespace => 'r8',:name => 'test_apache'},
{:namespace => 'dtk17',:name => 'dario_test'},
{:namespace => 'dtk17',:name => 'test_service'}
]

IMPORT_COMPONENTS = false
IMPORT_SERVICES = false

EXPORT_COMPONENTS = true
EXPORT_SERVICES = true


# DEBUG SNIPPET >>>> REMOVE <<<<
require 'rubygems'
require 'ap'

if IMPORT_COMPONENTS
  components.each do |comp|
    ap "dtk module import-dtkn #{comp[:namespace]}/#{comp[:name]}"
    output = `dtk module import-dtkn #{comp[:namespace]}/#{comp[:name]}`
    ap output
  end
end


if IMPORT_SERVICES
  services.each do |comp|
    ap ">>>>>> dtk service import-dtkn #{comp[:namespace]}/#{comp[:name]}"
    output = `dtk service import-dtkn #{comp[:namespace]}/#{comp[:name]}`
    ap output
  end
end

if EXPORT_COMPONENTS
  components.each do |comp|
    ap "dtk module #{comp[:name]} create-on-dtkn #{comp[:namespace]}/#{comp[:name]}"
    output = `dtk module #{comp[:name]} create-on-dtkn #{comp[:namespace]}/#{comp[:name]}`
    ap output
  end
end

if EXPORT_SERVICES
  services.each do |comp|
    ap "dtk service #{comp[:name]} create-on-dtkn #{comp[:namespace]}/#{comp[:name]}"
    output = `dtk service #{comp[:name]} create-on-dtkn #{comp[:namespace]}/#{comp[:name]}`
    ap output
  end
end

