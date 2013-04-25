class dtk_client($server_hostname)
{
  include dtk_client::params
  $repos = $dtk_client::params::repos
  $client_user = $dtk_client::params::client_user	
  $client_user_homedir = $dtk_client::params::client_user_homedir
  $dtk_username = $dtk_client::params::dtk_username
  $dtk_password = $dtk_client::params::dtk_password
  $client_src_path = $dtk_client::params::repo_targets['client']
  $dtk_client_bin_path = "${client_user_homedir}/${client_src_path}/bin"
  
  package {['thor','activesupport']:
    ensure   => 'installed',
    provider => 'gem'
  }

  user { $client_user: 
   home       => $client_homedir,
   shell      => '/bin/bash',
   managehome => true
  }  
  
  file { "${client_user_homedir}/.bash_profile":
    content => template('dtk_client/bash_profile.erb'),
    owner   => $client_user,
    require => User[$client_user]
  }
  
  file { "${client_user_homedir}/dtk/connection.conf":
    content => template('dtk_client/dtkclient.erb'),
    owner   => $client_user,
    require => User[$client_user]
  }
  
  file { '/etc/dtk/':
    ensure => directory,
    owner   => $client_user,
    require => User[$client_user]
  }
  
  file { '/etc/dtk/client.conf':
    content => template('dtk_client/client.conf.erb'),
    owner   => $client_user,
    require => File['/etc/dtk/']
  }
  dtk_client::github_repo { $repos:
    require => User[$client_user]
  }
}

#TODO: change to real app deployment; this only works when right keys already on node
define dtk_client::github_repo(
)
{
   $repo = $name
   include dtk_client::params
   $repo_url = $dtk_client::params::repo_urls[$repo]
   $target = $dtk_client::params::repo_targets[$repo]
   $client_user = $dtk_client::params::client_user
   $client_user_homedir = $dtk_client::params::client_user_homedir
     
   $repo_target_dir = "${client_user_homedir}/${target}"
   $git_clone_cmd = "git clone ${repo_url} ${repo_target_dir}"
   $chown_cmd = "chown -R ${client_user} ${repo_target_dir}"
   
   exec { "clone ${name}":
     command   => "${git_clone_cmd}; ${chown_cmd}",
     path      => ['/bin','/usr/bin'],
     logoutput => true,
     creates   => $repo_target_dir
   } 
}